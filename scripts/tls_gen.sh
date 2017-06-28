#!/bin/sh

#
# Generates and pushes the TLS assets required by Kubernetes to the remote etcd
# cluster for further retrieval by Kubernetes
#

set -e

CLUSTER_NAME="$1"
INTERNAL_DOMAIN="$2" # Route to the LB in front of our Kubernetes master cluster
K8S_SERVICE_IP="$3" # 10.<vpc-number>.128.1

echo "[INFO] Generating TLS assets for our Kubernetes cluster named $CLUSTER_NAME..."

echo "[INFO] Let's get started and create a Certification Authority for our cluster..."

tlsdir="./tls/${CLUSTER_NAME}"

echo "[INFO] Generating a root key to be put under ./tls/${CLUSTER_NAME}/ca.key ..."

mkdir -p "${tlsdir}"
openssl genrsa -out "${tlsdir}/ca.key"
openssl req -x509 -new -nodes -key "${tlsdir}/ca.key" -days 10000 -out "${tlsdir}/ca.pem" -subj "/CN=$CLUSTER_NAME-ca"

echo "[INFO] Now generating the certificates for Kubernetes API server under ${tlsdir}/apiserver.{key,pem}..."
echo "[INFO] First of all, let's generate an openssl.cnf config ..."

cat <<EOF > "${tlsdir}/openssl.cnf"
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.${CLUSTER_NAME}
DNS.5 = k8s.${CLUSTER_NAME}.${INTERNAL_DOMAIN}
DNS.6 = localhost
IP.1 = ${K8S_SERVICE_IP}
IP.2 = 127.0.0.1
EOF

echo "[INFO] Great, now let's generate a certificate for Kubernetes' API servers..."

openssl genrsa -out "${tlsdir}/apiserver.key" 2048
openssl req -new -key "${tlsdir}/apiserver.key" -out "${tlsdir}/apiserver.csr" -subj "/CN=${CLUSTER_NAME}-apiserver" -config "${tlsdir}/openssl.cnf"
openssl x509 -req -in "${tlsdir}/apiserver.csr" -CA "${tlsdir}/ca.pem" -CAkey "${tlsdir}/ca.key" -CAcreateserial -out "${tlsdir}/apiserver.pem" -days 365 -extensions v3_req -extfile "${tlsdir}/openssl.cnf"

echo "[INFO] Let's generate a cluster admin key for us to connect to our Kubernetes API server and have some fun with deployed containers..."
openssl genrsa -out "${tlsdir}/administrator.key" 2048
openssl req -new -key "${tlsdir}/administrator.key" -out "${tlsdir}/administrator.csr" -subj "/CN=kube-admin"
openssl x509 -req -in "${tlsdir}/administrator.csr" -CA "${tlsdir}/ca.pem" -CAkey "${tlsdir}/ca.key" -CAcreateserial -out "${tlsdir}/administrator.pem" -days 365

echo "[INFO] Let's generate indented versions of our CA & API certs for CoreOS' cloud-config"
sed 's/^/      /g'  ${tlsdir}/ca.key > ${tlsdir}/ca.indented.key
sed 's/^/      /g'  ${tlsdir}/ca.pem > ${tlsdir}/ca.indented.pem
sed 's/^/      /g'  ${tlsdir}/apiserver.key > ${tlsdir}/apiserver.indented.key
sed 's/^/      /g'  ${tlsdir}/apiserver.pem > ${tlsdir}/apiserver.indented.pem

echo "[INFO] Ok darling, we've got all our certificates. Now let's use them to provision and access a Kubernetes cluster"
