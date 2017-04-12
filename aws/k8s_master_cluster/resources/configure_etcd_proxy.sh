      #!/bin/bash

      #
      # Adds the current node to an existing etcd cluster behind a load-balancer
      #
      # It won't start etcd though, that means that this script has to be
      # executed by systemd before etcd tries to start. And the good thing is that's
      # exactly what systemd has been made up for :)
      #
      # Maintainer: Etienne Lafarge <etienne@rythm.co>
      #

      ETCD_ENDPOINT="$1"
      ETCD_VERSION="$2"

      cluster_conf=$(etcdctl --endpoints="${ETCD_ENDPOINT}" member list)
      cluster_available="$?"

      if [[ "$cluster_available" -ne 0 ]]; then
        echo "Etcd cluster couldn't be contacted"
        exit 12
      fi

      etcd_endpoints="$(awk '{print $4}' <<< "$cluster_conf" | sed 's/clientURLs=http:\/\///g' | tr '\n' ','| rev | cut -c 2- | rev)"
      # If we found a cluster and managed to add the current node onto it, let's
      # configure etcd to use it !
      mkdir -p /etc/systemd/system/etcd-member.service.d
      cat <<EOF > /etc/systemd/system/etcd-member.service.d/40-etcd-gateway.conf
      [Service]
      Environment="ETCD_IMAGE_TAG=${ETCD_VERSION}"
      ExecStart=
      ExecStart=/usr/lib/coreos/etcd-wrapper gateway start \
                    --listen-addr=0.0.0.0:2379 \
                    --endpoints=${etcd_endpoints}
      EOF

      echo "ectd gateway systemd service has been configured accordingly"
      systemctl daemon-reload
      echo "All set, etcd gateway should start with the appropriate configuration and give this node access to the whole etcd cluster..."
      exit 0

