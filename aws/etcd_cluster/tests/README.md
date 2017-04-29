Tests for the Terranetes etcd cluster module
============================================

Tested features
---------------

- Spawn a 3 node cluster
- cluster is healthy at the end, node count is 3
- unhealthy nodes are replaced sucessfully with new ones thanks to the ELB
- stop `etcd-member.service` on a node and make sure a new one pops in within
  5 minutes + ELB health check time (resilience to service crash)
- stop `etcd-member.service` on a node, corrupt the etcd data dir
  (`rm -rf /var/lib/etcd/*` should be fine), restart it and make sure the
  node is replaced within 5 minutes + ELB health check time (resilience to data
  deletion)
