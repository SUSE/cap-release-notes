# Notes for installing CAP on CaaSP

## General

* The port 2793 has to be open on the workers, for terraform in the
'secgroup_worker' resource :

```
rule {
  from_port   = 2793
  to_port     = 2793
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}


rule {
  from_port   = 2793
  to_port     = 2793
  ip_protocol = "udp"
  cidr        = "0.0.0.0/0"
}
```

* Designate DNS is configured but it does not support wildcards, hence,
I had to manually
configure these records :

```
lc.qa.cloud.caasp.suse.net.                    A               10.84.72.127
api.lc.qa.cloud.caasp.suse.net.             CNAME    
lc.qa.cloud.caasp.suse.net.
scf.uaa.lc.qa.cloud.caasp.suse.net.    CNAME     lc.qa.cloud.caasp.suse.net.
uaa.lc.qa.cloud.caasp.suse.net.           CNAME    
lc.qa.cloud.caasp.suse.net.
```

--> 10.84.72.127 is the floating IP of the Kubernetes worker with the
private IP 10.0.6.18

--> The content of scf-config-values.yaml :

```yaml
---
env:
    CLUSTER_ADMIN_PASSWORD: susetesting
    DOMAIN: lc.qa.cloud.caasp.suse.net
    UAA_ADMIN_CLIENT_SECRET: uaa-admin-client-secret
    UAA_HOST: uaa.lc.qa.cloud.caasp.suse.net
    UAA_PORT: 2793
kube:
    external_ip: 10.0.6.18
    storage_class:
        persistent: persistent
```

## Connecting to CEPH cluster

* For RBD StorageClass /etc/ceph/ceph.conf and
/etc/ceph/ceph.client.admin.keyring
must be present on the Kubernetes masters so the masters can dynamically
create the PVC.

```
---
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: persistent
provisioner: kubernetes.io/rbd
parameters:
  monitors: 10.0.5.245:6789,10.0.5.250:6789,10.0.5.247:6789
  adminId: admin
  adminSecretName: ceph-secret-admin
  adminSecretNamespace: default
  pool: k8s
  userId: admin
  userSecretName: ceph-secret-admin
```

* In Kubernetes, ceph secret must exist in all namespaces, so I created
them before installing the charts:

```
kubectl create namespace uaa
kubectl create secret generic ceph-secret-admin
--from-file=ceph-client-key --type=kubernetes.io/rbd --namespace=uaa
kubectl create namespace scf
kubectl create secret generic ceph-secret-admin
--from-file=ceph-client-key --type=kubernetes.io/rbd --namespace=scf
kubectl create namespace stratos
kubectl create secret generic ceph-secret-admin
--from-file=ceph-client-key --type=kubernetes.io/rbd --namespace=stratos
```

## Running CaaSP on OpenStack

There are OpenStack images of CaaSP which can be used to create a Kubernetes cluster running on top of OpenStack. There are a few things which need to be considered to make it suitable to run CAP:

### Provide enough disk space for images

The default is to provide 40 GB of disk space to the CaaSP nodes. This is not sufficient for CAP. So use a machine flavor with a bigger disk and let is use the additional free space for storing images.

Use the free space, create a partition on it, format it with btrfs and mount it as
`/var/lib/docker` before you start importing any containers. If you resize the root filesystem to the full disk, you have very big root filesystem and still no space to store the containers without a big performance penalty.
