OpenVPN Server for Kubernetes
=============================

This alpine-based Docker image packages an OpenVPN server that can be deployed
on a Kubernetes cluster to give your team's OpenVPN clients seamless access to
Kubernetes pods and services IP addresses.

It is mostly based off [John Felten's work](https://github.com/jfelten/openvpn-docker).
However, it stores the server TLS secrets and client certs in Kubernetes secrets
instead of using a Persistent Volume.

It can seamlessly be deployed as part of the "ingress" flavor of our Terranetes
boilerplate cluster.

Note that you'll need an OpenVPN client and - optionnally - DNSMasq to route
only relevant DNS queries to `kube-dns`. Such a thing can be found
[here](../openvpn-client-docker).

Env. Variables
--------------

Configuration is done through environment variables exclusively:
```
K8S_SECRET_NAMESPACE  the namespace under which Kubernetes secrets will live
SERVER_TLS_SECRET     secret name for the server's TLS assets
CLIENT_CERTS_SECRET   secret name for the client certs

OVPN_PROTO            protocol to use (default: tcp)
OVPN_NETWORK          openvpn network (default: 10.240.0.0)
OVPN_SUBNET           openvpn network subnet mask (default: 255.255.255.0)
OVPN_PORT             openvpn server port (default: 42062, to change ;-))
OVPN_K8S_POD_NETWORK  pod network
OVPN_K8S_POD_SUBNET   pod subnet
```

Maintainers
-----------
* Étienne Lafarge <etienne.lafarge@gmail.com>
