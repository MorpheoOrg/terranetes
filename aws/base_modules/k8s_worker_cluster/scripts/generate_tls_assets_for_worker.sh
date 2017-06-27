      #!/bin/bash

      #
      # Generates TLS certificates for a worker node
      #
      # Maintainer: Etienne Lafarge <etienne@rythm.co>
      #

      WORKER_IP="$1"
      WORKER_FQDN="$2"

      echo "[INFO] Generating TLS certificate for worker node ${WORKER_FQDN}..."

      cat <<EOF > /etc/kubernetes/ssl/openssl-worker.cnf
      [req]
      req_extensions = v3_req
      distinguished_name = req_distinguished_name
      [req_distinguished_name]
      [ v3_req ]
      basicConstraints = CA:FALSE
      keyUsage = nonRepudiation, digitalSignature, keyEncipherment
      subjectAltName = @alt_names
      [alt_names]
      IP.1 = ${WORKER_IP}
      EOF

      openssl genrsa -out /etc/kubernetes/ssl/worker.key 2048
      openssl req -new -key /etc/kubernetes/ssl/worker.key -out /etc/kubernetes/ssl/worker.csr -subj "/CN=${WORKER_FQDN}" -config /etc/kubernetes/ssl/openssl-worker.cnf
      openssl x509 -req -in /etc/kubernetes/ssl/worker.csr -CA /etc/kubernetes/ssl/ca.pem -CAkey /etc/kubernetes/ssl/ca.key -CAcreateserial -out /etc/kubernetes/ssl/worker.pem -days 365 -extensions v3_req -extfile /etc/kubernetes/ssl/openssl-worker.cnf

      echo "[GREAT SUCCESS] Certs generated successfully!"
