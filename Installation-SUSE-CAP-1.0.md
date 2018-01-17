# Installing SUSE Cloud Application Platform 1.0

*These are instructions for installing the latest SUSE Cloud Application Platform 1.0 milestone release. The product is sill in pre-release stage. The final product release will be documented in the official documentation.*

These instructions are assuming that you have a suitable Kubernetes setup such as SUSE CaaS Platform with active Kube DNS and a storage class for persistant data. Details how to check that can be found in the [SUSE Cloud Foundry Wiki](https://github.com/SUSE/scf/wiki/How-to-Install-SCF#requirements-for-kubernetes).

## Configuring the deployment

Create a scf-config-values.yaml file with the settings required for the install. Copy the below as a template for this file and modify the values to suit your installation.

```yaml
env:
    # Password for user 'admin' in the cluster
    CLUSTER_ADMIN_PASSWORD: changeme

    # Domain for SCF. DNS for *.DOMAIN must point to a kube node's (not master)
    # external ip address.
    DOMAIN: cf-dev.io

    # Password for SCF to authenticate with UAA
    UAA_ADMIN_CLIENT_SECRET: uaa-admin-client-secret

    # UAA host/port that SCF will talk to. If you have a custom UAA
    # provide its host and port here. If you are using the UAA that comes
    # with the SCF distribution, simply use the two values below and
    # substitute the cf-dev.io for your DOMAIN used above.
    UAA_HOST: uaa.cf-dev.io
    UAA_PORT: 2793
kube:
    # The IP address assigned to the kube node pointed to by the domain.
    external_ip: 192.168.77.77
    storage_class:
        # Make sure to change the value in here to whatever storage class you use
        persistent: "persistent"
        shared: "shared"
    # The registry the images will be fetched from. The values below should work for
    # a default installation from the suse registry.
    registry:
       hostname: "registry.suse.com"
       username: ""
       password: ""
    organization: "cap"

    # The next line is needed for CaaS Platform 2, but should _not_ be there for CaaS Platform 1
    auth: rbac
```

If you are deploying to a Caas Platform with SES you need to prepare the environment using these commands:

```
kubectl create namespace uaa
kubectl get secret ceph-secret-admin -o json --namespace default | sed 's/"namespace": "default"/"namespace": "uaa"/' | kubectl create -f -
kubectl create namespace scf
kubectl get secret ceph-secret-admin -o json --namespace default | sed 's/"namespace": "default"/"namespace": "scf"/' | kubectl create -f -
kubectl create namespace stratos
kubectl get secret ceph-secret-admin -o json --namespace default | sed 's/"namespace": "default"/"namespace": "stratos"/' | kubectl create -f -
```

## Deploy using Helm

*If you haven't installed the helm client follow the instructions at https://docs.helm.sh/using_helm/#quickstart*

### Add the CAP Helm Chart repository:

```
helm repo add suse https://kubernetes-charts.suse.com/
```

### Deploy Cloud Foundry

1. Deploy UAA

    ```
    helm install suse/uaa \
        --namespace uaa \
        --values scf-config-values.yaml
    ```

1. Wait until the `uaa:secret-generator` pod was run and disappeared:

    ```
    watch -c 'kubectl get pods --all-namespaces'
    ```

    Then copy the UAA CA Cert to later give to SCF

    ```
    CA_CERT="$(kubectl get secret secret --namespace uaa -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"
    ```

1. With UAA deployed, use Helm to deploy SCF.

    ```
    helm install suse/cf \
        --namespace scf \
        --values scf-config-values.yaml \
        --set "env.UAA_CA_CERT=${CA_CERT}"
    ```

1. Wait for everything to be ready:

    ```
    watch -c 'kubectl get pods --all-namespaces'
    ```

    Stop watching when all pods show state `Running` and Ready is `n/n` (instead of `k/n`, `k < n`).

## Deploy Stratos, the Console UI

```
helm install suse/console --namespace=stratos --values scf-config-values.yaml
```
> NOTE: This will automatically configure the UI with the SCF and UAA configuration from your `scf-config-values.yaml` file. You may omit `--values scf-config-values.yaml` and configure the UI via the web-based setup flow.

> NOTE: If you don't have a default storage class, you will also need to add to this command line:

```
--set storageClass=<STORAGE_CLASS_NAME>
```

## Additional resources

This document describes the basic installation instructions for SUSE Cloud Application Platform. This information will be in the [official SUSE CAP documentation](http://docserv.suse.de/documents/#CAP_1). Some more details about special use cases can currently be found in the instructions for the open source projects:[SUSE Cloud Foundry](https://github.com/SUSE/scf/wiki/How-to-Install-SCF) and [Stratos UI](https://github.com/SUSE/stratos-ui/tree/master/deploy/kubernetes). Generic Cloud Foundry documentation is in the [upstream docs](https://docs.cloudfoundry.org).