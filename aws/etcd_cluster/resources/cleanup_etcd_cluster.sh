      #!/bin/bash

      #
      # Polls the cluster for dead nodes and removes them in order to maintain a good
      # absolute majority (dead people don't vote any more).
      #
      # Maintainer: Étienne Lafarge <etienne@rythm.co>
      #

      ETCD_ENDPOINT="$1"

      unhealthy_nodes="$(etcdctl --endpoints="${ETCD_ENDPOINT}" cluster-health | grep unreachable | awk '{print $2}')"

      if [[ -z "$unhealthy_nodes" ]]; then
        echo "No unhealthy node to remove"
        exit 0
      fi

      while read -r member_id; do
        echo "Removing unhealthy node $member_id"
        etcdctl --endpoints="${ETCD_ENDPOINT}" member remove "$member_id"
      done <<< "$unhealthy_nodes"
      exit 0
