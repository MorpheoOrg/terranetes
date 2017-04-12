      #!/bin/bash

      #
      # Adds the current node to an existing etcd cluster behind a load-balancer
      #
      # It won't start etcd though, that means that this script has to be
      # executed by systemd before etcd tries to start. And the good thing is that's
      # exactly what systemd has been made for :)
      #
      # Maintainer: Etienne Lafarge <etienne@rythm.co>
      #

      ETCD_VERSION="$1"
      ETCD_ENDPOINT="$2"
      IP="$3"

      # Let's build the etcdctl command accordingly
      cluster_config="$(etcdctl --endpoints="${ETCD_ENDPOINT}" member list)"
      etcd_endpoints="$(awk '{print $4}' <<< "$cluster_config" | sed 's/clientURLs=http:\/\///g' | tr '\n' ','| rev | cut -c 2- | rev)"
      etcdctl_cmd="docker run --rm --net=host --env ETCDCTL_API=3 quay.io/coreos/etcd:${ETCD_VERSION} /usr/local/bin/etcdctl --endpoints=${etcd_endpoints}"

      cluster_conf="$($etcdctl_cmd member add --peer-urls="http://$IP:2380" "etcd_$IP")"
      cluster_available="$?"

      rm -rf /var/lib/etcd/*

      if [[ "$cluster_available" -eq 0 ]]; then
        # If we found a cluster and managed to add the current node onto it, let's
        # configure etcd to use it !
        echo "New etcd member was added sucessfully, here lies its initial configuration:"
        echo "$cluster_conf"
        mkdir -p /etc/systemd/system/etcd-member.service.d/
        rm -f /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf || echo "No conf to remove"
        echo "$cluster_conf" >> /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i '/^$/d' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i 's/"//g' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i 's/^/"/' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i 's/$/"/' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i 's/^/Environment=/g' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        sed -i '1s/^.*$/[Service]/g' /etc/systemd/system/etcd-member.service.d/99-etcd-reconfigure.conf
        systemctl daemon-reload
        echo "All set, etcd should start with the appropriate configuration and discover its peers..."
        exit 0
      else
        echo "Error adding current node to the etcd cluster"
        exit 12
      fi
