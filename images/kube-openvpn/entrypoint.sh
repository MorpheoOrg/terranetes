#!/bin/sh

#
# Sets up a CA for an OpenVPN server running in a Kubernetes cluster if not
# already done and runs the VPN server.
#
# Env. variables:
#  * OVPN_PROTO: protocol to use for OpenVPN (default: tcp)
#  * OVPN_NETWORK: network to connect to
#  * OVPN_SUBNET: openvpn subnet mask
#  * OVPN_PORT: port on which OpenVPN will be listening on
#  * OVPN_K8S_POD_NETWORK: network on which pods are living
#  * OVPN_K8S_POD_SUBNET: subnet mask for the pod network
#

set -e

EASY_RSA_LOC="/etc/openvpn/certs"

if [ -s "/init_certs/pki/ca.crt" ]; then
  echo "[INFO] Found existing server certs, re-using them..."
  cp -Rf /init_certs/pki "${EASY_RSA_LOC}/pki"
  chmod -R 600 $EASY_RSA_LOC/pki
else
  echo "[INFO] No pre-existing server certs, creating them..."
  cp -R /usr/share/easy-rsa/* $EASY_RSA_LOC
  cd $EASY_RSA_LOC
  ./easyrsa init-pki
  printf "ca\n" | ./easyrsa build-ca nopass
  ./easyrsa build-server-full server nopass
  ./easyrsa gen-dh

  echo "[INFO] Storing generated certs as Kubernetes secrets under $K8S_SECRET_NAMESPACE/$SERVER_TLS_SECRET..."

  kubectl --namespace "$K8S_SECRET_NAMESPACE" delete secret "$SERVER_TLS_SECRET"
  kubectl --namespace "$K8S_SECRET_NAMESPACE" create \
    secret generic "$SERVER_TLS_SECRET" \
    --from-file=pki/ca.crt \
    --from-file=pki/dh.pem \
    --from-file=pki/private/server.key

  kubectl --namespace "$K8S_SECRET_NAMESPACE" delete secret "$CLIENT_CERTS_SECRET"
  kubectl --namespace "$K8S_SECRET_NAMESPACE" create \
    secret generic "$CLIENT_CERTS_SECRET" \
    --from-file pki/issued
fi

echo "[INFO] Setting iptable rule for OpenVPN..."
iptables -t nat -A POSTROUTING -s "$OVPN_NETWORK/$OVPN_SUBNET" -o eth0 -j MASQUERADE
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
  mknod /dev/net/tun c 10 200
fi
POD_IP="$(ip route get 8.8.8.8 | awk '/8.8.8.8/ {print $NF}')"
OVPN_POD_NETWORK="$(echo "$POD_IP" | cut -d"." -f1-3).0"

DNS="$(grep -v '^#' < /etc/resolv.conf | grep nameserver | awk '{print $2}')"
SEARCH=$(grep -v '^#' < /etc/resolv.conf | grep search | awk '{$1=""; print $0}')

cp /kube-openvpn/openvpn.template.conf /etc/openvpn/openvpn.conf

sed 's/OVPN_POD_NETWORK/'"$OVPN_POD_NETWORK"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_NETWORK/'"$OVPN_NETWORK"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_SUBNET/'"$OVPN_SUBNET"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_PROTO/'"$OVPN_PROTO"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_PORT/'"$OVPN_PORT"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_K8S_POD_NETWORK/'"$OVPN_K8S_POD_NETWORK"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_K8S_POD_SUBNET/'"$OVPN_K8S_POD_SUBNET"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_K8S_SEARCH/'"$SEARCH"'/g' -i /etc/openvpn/openvpn.conf
sed 's/OVPN_K8S_DNS/'"$DNS"'/g' -i /etc/openvpn/openvpn.conf

openvpn --config /etc/openvpn/openvpn.conf
