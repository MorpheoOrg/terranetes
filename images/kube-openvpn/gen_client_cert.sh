#!/bin/sh

#
# Generates a Cert for a given client to connect to OpenVPN
#

EASY_RSA_LOC="/etc/openvpn/certs"
CLIENT_NAME="$1"

cd "${EASY_RSA_LOC}" || exit 12

./easyrsa build-client-full "$CLIENT_NAME" nopass

cat >"${EASY_RSA_LOC}/pki/$CLIENT_NAME.ovpn" <<EOF
client
nobind
dev tun
<key>
$(cat "${EASY_RSA_LOC}/pki/private/$CLIENT_NAME.key")
</key>
<cert>
$(cat "${EASY_RSA_LOC}/pki/issued/$CLIENT_NAME.crt")
</cert>
<ca>
$(cat "${EASY_RSA_LOC}/pki/ca.crt")
</ca>
<dh>
$(cat "${EASY_RSA_LOC}/pki/dh.pem")
</dh>
<connection>
proto ${OVPN_PROTO}
remote ${OVPN_EXTERNAL_ENDPOINT} ${OVPN_PORT}
</connection>
EOF

# Let's remove the client key from the server
rm "${EASY_RSA_LOC}/pki/private/$CLIENT_NAME.key"

kubectl --namespace "$K8S_SECRET_NAMESPACE" delete secret "$CLIENT_CERTS_SECRET"
kubectl --namespace "$K8S_SECRET_NAMESPACE" create \
  secret "$CLIENT_CERTS_SECRET" \
  --from-file pki/issued

echo "[INFO] Your OpenVPN config is waiting for you on the OpenVPN pod under ${EASY_RSA_LOC}/pki/$CLIENT_NAME.ovpn, please copy it on your local machine and remove the file from the pod."
