TerraNetes
==========

TL;DR
-----
Deploy a self-managed, production-grade Kubernetes-on-top-of-Container-Linux
cluster on AWS... in one command. All you need to do is select the components
you want (instance type, initial size, CoreOS AMI and channel...)

##### Why Terraform ?
* awesome AWS support and possibility to write the same design implementation on
  other platforms (OpenStack, GCE & Azure)
* the best infrastructure-as-code tool we found in terms of state transition, it
  also seems to be the one the community fell in love for
* modules are a great way to reshape your Kubernetes cluster, in particular, it
  enables us to easily have different worker clusters with different specs
  (amount of RAM or disk, number of CPU cores, GPU...). We're running different
  types of workloads (api servers, data mining, machine learning...) and have
  different hardware requirements for each of these tasks. Terraform makes it
  easy to create specialized worker clusters... and Kubernetes to assign
  specialized pods on the appropriate cluster.

##### Why Container Linux ? (ex. CoreOS)
* it's targeted at running containers, especially on top of Kubernetes
* supervising tools (`foreman`, `supervisord`...) are replaced by...`systemd` !
* no need for complex live VM provisioning tools (Ansible, Chef, Salt...)
* no need to provision VM images either: one just needs to start the `stable`
  Container Linux image and put a `cloud-config` file in it (no `packer` and no
  need to version your VM images, CoreOS does all that for us)
* automated & coordinated cluster upgrade rollouts with `locksmith`: one just
  needs to create the cluster... and let it live :)

##### Why Kubernetes ?
... if you ended up on this page, you already know why :)

Getting started
---------------

### 1 - Create TLS certificates for your cluster

First of all, you'll need to generate a root CA keypair to sign the certificates
of the Kubernetes APIServer, the workers and for people who need to kubectl on
your Kubernetes cluster. There's a bash script that automates the whole process
[here](https://github.com/MorpheoOrg/terranetes/blob/master/aws/scripts/tls-gen.sh)
(you'll essentially need to have OpenSSL installed).

```shell
./tls-gen.sh <cluster-name> <internal-domain> <k8s-service-ip>

# Example
./tls-gen.sh my-cluster my-company.int 10.1.128.1
```

* The cluster name is the name you'll give to this VPC/Kubernetes cluster
* The internal domain in the domain that will be used by routes pointing to your
  internal etcd and Kubernetes master ELBs. They result in an **internal**
  Route53 zone being used. It's discouraged to use your *real* external domain
  (just use the `.int` extension instead of `.com`, `.io`, `.co` etc.)
* The Kubernetes service IP usually is the first IP in the range of IPs alloted
  to your Kubernetes services, in our design, it will always be
  `10.<vpc_number+1>.128.1`. We'll see later what `vpc_number` means (IP
  addressing schemes are described in the "Cluster Design Principles" section of
  this document.

#### Exposing your master cluster (at your own peril...)

If you're planning to access the Kubernetes master without using the bastion or
a VPN server (by exposing it using an Ingress rule and a TCP ingress controller
like
[NGinX](https://github.com/kubernetes/ingress/tree/master/controllers/nginx)),
you'll need to add the domain name you'll be using
[here](https://github.com/MorpheoOrg/terranetes/blob/master/aws/scripts/tls-gen.sh#L44).

Note that you can add this name later, re-run the script, re-run `terraform
apply` and kill your old master without having to tear down the entire cluster.
In a multi-master setup, you can even perform the upgrade in a blue/green, zero
downtime fashion (however running a master-less Kubernetes cluster for a couple
of minutes is also possible but deployments and all kubectl interaction will of
course be impossible during the master downtime frame).

SSH tunnelling to the master via the bastion and a rule in your `/etc/hosts` or
deploying OpenVPN in Kubernetes or on VMs in your Kubernetes VPC are the
recommended way to access your master cluster though. Even though all
connections are authenticatced and encrypted, exposing such an important piece
of your infrastructure seems a bit... risky, if you know what I mean :)

### 2 - Configure and spawn your Kubernetes master (& etcd) cluster

### 3 - Configure and spawn your worker clusters (& add Kubernetes add-ons)

### 4 (Optional) - Safely route your traffic through ingress controllers

TODO

#### Why it is essential if you want to avoid 5xx errors at all cost

TODO

Talk about the limits of LoadBalancer services and kube-proxy on AWS (why the
hell did the Kubernetes guys hardcode their ELB health check parameters ?!)

#### An example with the Traefik ingress controller

TODO (mention that Traefik can't act as a pure TCP/UDP proxy for now, if you
need that, you'll want to use the NGinX ingress controller instead)

### Appendix A: Tuning your Kernel parameters with system drop-in units

TODO

### Appendix B: Adding systemd units (monitoring agents, backup machines) to your clusters (including etcd and the bastion)

TODO

* SystemD is your friend again
* The importance of collecting, auditing and alerting on your bastion's SSH logs

### Appendix C: some pieces of advice on the cluster configuration

TODO

* `etcd` is THE (only) crucial piece. Pet it with all your love, be careful with
  `t2` instances and monitor it extensively ! (also it may be time to get
  PagerDuty alerts an your phone in case consensus is about to be lost)
* If you're using stateful sets, the Kubernetes cluster auto-scaler will want
  you to create one ASG per AZ. But it can still spread your nodes accross
  multiple ASGs in multiple AZs even you really want that HA postgres cluster to
  be zone-failure tolerant (and therefore Highly Available for real)

Design Philosophy
-----------------

Simplicity, robustness and automation are at the core of this cluster design.
Like most sysadmins - and most computer scientists in general - we're lazy and
hate repeating ourselves. Also, this cluster was designed with high scale and
high availability in mind

### Design overview

Schema


### Network Topology, in detail

It doesn't seem very flexible, however, it spans as many IPs as
possible and allows for up to `2^15` pods/services per cluster (32K pods). If
you need more you can then use VPC peering connections to federate up to 128 of
these clusters in an single AWS region. Each would be an independant k8s cluster
but since IPs don't overlap, they can also talk to each other directly if
needed. We didn't span the entire `10.0.0.0/24` space since some people might be
willing to have multiple Kubernetes clusters for different purposes (Prod,
Staging, Monitoring, CI...) but still be able to bind them with an AWS peering
connection. However if this 4 million pods limit is an issue for anyone, making
the CIDRs more configurable is definitely a possibility ;-)

### Cluster administration

* Monitoring, scaling and getting backups for etcd (always one at a time for
  quorum sake!)

### TODO

* ELB health checks on the etcd cluster as well as the Kubernetes master
* Add a CNI plugin (network policies at the container network overlay level)
* Stronger network polices at the machine level (security groups)
* Unit-tested etcd bootstrap and upgrade manager in Go, in a `rkt` image instead
  of this dirty bash script
* Use the `etcd grpc proxy` instead of an ELB and this same Go program for
  service discovery with the AWS SDK. Traffic to etcd can be routed by the grpc
  proxy on the master nodes, via the master ELB (15 bucks/month saved...). The
  `etcd gateway` sticks to one node instead of spreading the load... we can
  definitely do better.
* TLS on etcd as well
* Create a `proposals/todo` folder and move this section over there!

### Authors

* Étienne Lafarge <etienne@morpheo.co>

We'd really love to make that list longer and diverse in terms of e-mail
domains.

We'd love to add an `./openstack` folder to this repo. at some points. Research
labs love OpenStack :)

#### Project history

Started in August 2016, as part of my final year internship at Rythm. The goal
being to easily scale our APIs and, most importantly, our machine learning
pipeline. It first got deployed in production in October 2016. Only one cluster
failure happened since that date, when migrating the KV store from `etcd2` to
`etcd3`.

We're starting using it in multi-cluster scenario for the Morpheo project, using
GPU instances for our machine learning and data analytics clusters. It should be
flexible enough for all containerizable workloads though (and even for non
cloud-native stateful apps deployed as Kubernetes StatefulSets).

Since Morpheo is open-source and since deploying a production Kubernetes cluster
on AWS may interest a lot of people, we decided to release some of our
infrastructure code as well so that the community could benefit from it (and so
that we could benefit from feedbacks, suggestions and improvement from the
community as well).

We're aware that the CECILL3 licensing may be misunderstood. If you carefully
look at it, it's simply a transcription of the GNU GPLv3 that is more compatible
with french intellectual property laws. In short, that's just the GPLv3 with
another name. You can use this code as a library in your proprietary
infrastructure (and so do we), but all changes brought to the code itself for
non-private use must be made public and should carry a mention of what was
changed (explicit commit/PR messages are just fine).
