# Notes for installing CAP on CaaSP

## General

* The port 2793 has to be open on the workers, for terraform in the
'secgroup_worker' resource :

```
# diego-access-public (SCF)
rule {
  from_port   = 2222
  to_port     = 2222
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}

# uaa-pulic (UAA)
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

# router-public (SCF)
rule {
  from_port   = 4443
  to_port     = 4443
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}

# tcp-router-public (SCF)
rule {
  from_port   = 2341
  to_port     = 2341
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}

# tcp-router-public (SCF)
rule {
  from_port   = 20000
  to_port     = 20008
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}

# stultified-unicorn-ui-next (STRATOS)
rule {
  from_port   = 8443
  to_port     = 30820
  ip_protocol = "tcp"
  cidr        = "0.0.0.0/0"
}
```

* Designate DNS is configured and it supports wildcards, so for example:

```
lc.qa.cloud.caasp.suse.net.	  A 	      10.84.72.127
*.lc.qa.cloud.caasp.suse.net.	CNAME 	  lc.qa.cloud.caasp.suse.net.
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

* For RBD StorageClass 

Only **if you don't have or don't want** your secrets stored in Kubernetes, 
/etc/ceph/ceph.conf and /etc/ceph/ceph.client.admin.keyring must be present on 
the Kubernetes masters so the masters can dynamically create the PVC.

For testing purposes only, I used the admin for both admin/user.

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

There are OpenStack images of CaaSP which can be used to create a Kubernetes cluster running on top of OpenStack.


### Considerations prior to deploying

* Provide enough disk space for images

  The default is to provide 40 GB of disk space to the CaaSP nodes. This is not sufficient for CAP. So use a machine flavor with a bigger disk and let it use the additional free space for storing images (Commands on how to resize the CaaSP node root fs are provided in the instructions below).


### Initial preparations

The following steps only have to be done once before the initial CaaSP deployment. For following deployments of CaaSP this has no to be redone but already created elements can be reused. The deployment of CaaSP on OpenStack is done using existing terraform rules with some additional steps required for running CAP on the CaaSP deployment.


* Start with downloading and sourcing the openrc.sh file for OpenStack API access

  ```
  firefox https://$OPENSTACK/project/access_and_security/api_access/openrc/
  . openrc.sh
  ```

  *Note* You will have to login to download the file. The filename might have a prefix named after the OpenStack project the file is for.


**Optional steps**

These step can be performed but are not mandatory. You can also use already existing OpenStack objects instead (e.g. if you do not have the permission to create projects or networks).

* Create a openstack project to run CaaSP in (e.g. caasp), add a user as admin and export the project to be used by terraform

  ```
  openstack project create --domain default --description "CaaSP Project" caasp
  openstack role add --project caasp --user admin admin
  export OS_PROJECT_NAME='caasp'
  ```

* Create a Openstack network plus a subnet for caasp (e.g. caasp-net) and add a router to the extrenal (e.g. floating) network

  ```
  openstack network create caasp-net
  openstack subnet create caasp_subnet --network caasp-net --subnet-range 10.0.2.0/24
  openstack router create caasp-net-router
  openstack router set caasp-net-router --external-gateway floating
  openstack router add subnet caasp-net-router caasp_subnet
  ```

**Mandatory Steps**

The following steps have to be done at least once in order to be able to deploy CaaSP and CAP on top of OpenStack


* Upload the CaaSPv2 image to OpenStack

  You can get the SUSE-CaaS-Platform-2.0-OpenStack-Cloud.x86_64-1.0.0-GM.qcow2 image (here)[https://download.suse.com/Download?buildid=tW8sXCIHrWE~] (SUSE customer account required).


  ```
  openstack image create --file SUSE-CaaS-Platform-2.0-OpenStack-Cloud.x86_64-1.0.0-GM.qcow2 SUSE-CaaS-Platform-2.0-GM
  ```

* Create a additional security group with rules needed for CAP

  ```
  openstack security group create cap --description "Allow CAP traffic"
  openstack security group rule create cap --protocol any --dst-port any --ethertype IPv4 --egress
  openstack security group rule create cap --protocol any --dst-port any --ethertype IPv6 --egress
  openstack security group rule create cap --protocol tcp --dst-port 20000:20008 --remote-ip 0.0.0.0/0
  openstack security group rule create cap --protocol tcp --dst-port 443:443 --remote-ip 0.0.0.0/0
  openstack security group rule create cap --protocol tcp --dst-port 2793:2793 --remote-ip 0.0.0.0/0
  openstack security group rule create cap --protocol tcp --dst-port 4443:4443 --remote-ip 0.0.0.0/0
  openstack security group rule create cap --protocol tcp --dst-port 80:80 --remote-ip 0.0.0.0/0
  openstack security group rule create cap --protocol tcp --dst-port 2222:2222 --remote-ip 0.0.0.0/0
  ```

* Clone the terraform script

  ```
  git clone git@github.com:kubic-project/automation.git
  cd automation/caasp-openstack-terraform
  ```

* Edit `openstack.tfvars`. Use the names of the just created OpenStack objects

  Example:
  ```
  image_name = "SUSE-CaaS-Platform-2.0-GM"
  internal_net = "caasp-net"
  external_net = "floating"
  admin_size = "m1.large"
  master_size = "m1.large"
  masters = 1
  worker_size = "m1.xlarge"
  workers = 2
  ```

* Initialize terraform

  ```
  terraform init
  ```


### Deploy CaaSP

* Source the openrc.sh file, set the project and deploy

  ```
  . openrc.sh
  export OS_PROJECT_NAME='caasp'
  ./caasp-openstack apply
  ```

* Wait for 5 - 10 minutes until all systems are up and running
* Get an overview of your CaaSP installation

  ```
  openstack server list
  ```

* Add the initial created `cap` security group to all CAP workers

  ```
  openstack server add security group caasp-worker0 cap
  openstack server add security group caasp-worker1 cap
  ```

* Access to CaaSP nodes

  For CAP you might have to log into the CaaSP master and nodes. To do so,
  use ssh with the ssh key in the `automation/caasp-openstack-terraform/ssh`
  dir to login as root.


### Bootstrap CaaSP

* Point your browser at the IP of the CaaSP admin node
* Create a new admin user
* On `Initial CaaS Platform Configuration`
  * _Admin node_ - the prefilled value (public/floating ip) needs to be replaced by the internal openstack caasp subnet ip of the CaaSP admin node
  * Enable the "Install Tiller" checkbox
* On `Bootstrap your CaaS Platform`
  * Click [Next]
* On `Select nodes and roles`
  * Click [Accept All nodes] and wait until they appear in the upper part of the page
  * Define master and nodes
  * Click [Next]
* On `Confirm bootstrap`
  * _External Kubernetes API FQDN_ - Enter the public(floating) IP from the CaaSP master with added .xip.io domain suffix
  * _External Dashboard FQDN_ - Enter the public(floating) IP from the CaaSP admin with added .xip.io omain suffix

### Prepare CaaSP for CAP

* Commands to run on the CaaSP master

  This is only necessary if you use hostpath as storage class
  ```
  perl -p -i -e 's@^(KUBE_CONTROLLER_MANAGER_ARGS=)"(.*)"@\1"\2 --enable-hostpath-provisioner"@' /etc/kubernetes/controller-manager
  mkdir -p /tmp/hostpath_pv
  chmod a+rwx /tmp/hostpath_pv
  systemctl restart kube-controller-manager.service
  ```

* Commands to run on the CaaSP nodes

  This is only necessary if you use hostpath as storage class
  ```
  mkdir -p /tmp/hostpath_pv
  chmod a+rwx /tmp/hostpath_pv
  ```

  Resize your root filesystem of the worker to match the disk provided by OpenStack
  ```
  growpart /dev/vda 3
  btrfs filesystem resize max /.snapshots
  ```
