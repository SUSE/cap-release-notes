# Setting up and using a service broker sidecar

We currently provide helm charts for two service brokers managing
access to [`MySQL`] and [`Postgres`] databases.

This document describes how to use these charts in the context of
a CAP cluster.

[`MySQL`]: #deploying-the-mysql-chart
[`Postgres`]: #deploying-the-postgresql-chart

# Prerequisites

- Helm must be configured; see [helm docs] if you need assistance.
- A working CAP deployment.

[helm docs]: https://docs.helm.sh/using_helm/#quickstart

# Deploying the MySQL chart

1. You need an external MySQL installation, with account credentials that allow
    creating and deleting both databases and users.

1. Configure the database access credentials.
    ```bash
    export DBHOST=…
    export DBPORT=…
    export DBUSER=…
    export DBPASS=…
    ```
    The necessary credentials are:

    | Name     | Description                      | Default
    | -------- | -------------------------------- | --
    | `DBHOST` | Host name of the database server |
    | `DBPORT` | Port of the database server      | 3306
    | `DBUSER` | Database user name               | `root`
    | `DBPASS` | Database user password           |

1. Configure the CAP access credentials:
    ```bash
    export NAMESPACE=…
    export CLUSTER_ADMIN_PASSWORD=…
    export DOMAIN=…
    export CF_CA_CERT=…
    export UAA_CA_CERT=…
    export SIDECAR_NAMESPACE=…
    ```
    The credentials are:

    | Name | Description | Sample command
    | --- | --- | ---
    | `NAMESPACE` | Namespace CAP was deployed in | `NAMESPACE="$(helm list --date --reverse | awk '/cf/ { print $NF }' | head -n1)"`
    | `REVISION` | The revision of the CAP deployment | `REVISION="$(helm list --date --reverse | awk '/cf/ { print $2 }' | head -n1)"`
    | `CLUSTER_ADMIN_PASSWORD` | The administrator password for the CAP deployment | `CLUSTER_ADMIN_PASSWORD="$(kubectl get secret --namespace $NAMESPACE secret-$REVISION -o jsonpath='{.data.cluster-admin-password}' | base64 -d)"`
    | `DOMAIN` | The domain that CAP is using for deployed applications | `DOMAIN="$(kubectl get pod --namespace $NAMESPACE api-0 -o jsonpath='{.spec.containers[0].env[?(@.name == "DOMAIN")].value}')"`
    | `CF_CA_CERT` | The certificate for the internal certificate authority for the CAP deployment | `CF_CA_CERT="$(kubectl get secret --namespace $NAMESPACE secret-$REVISION -o jsonpath='{.data.internal-ca-cert}' | base64 -d)"`
    | `UAA_CA_CERT` | The certificate for the internal certificate authority for the UAA deployment | `UAA_CA_CERT="$(kubectl get secret --namespace $NAMESPACE secret-$REVISION -o jsonpath='{.data.uaa-ca-cert}' | base64 -d)"`
    | `SIDECAR_NAMESPACE` | The Kubernetes to install the sidecar to; may be the same as the CAP namespace | `SIDECAR_NAMESPACE=${NAMESPACE}`

1. Ensure that you have the SUSE helm chart repository available:
    ```bash
    helm repo add suse https://kubernetes-charts.suse.com/
    ```

1. Install the helm chart:
    ```bash
    helm install suse/cf-usb-sidecar-mysql \
        --namespace ${SIDECAR_NAMESPACE} \
        --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-mysql.${SIDECAR_NAMESPACE}:8081" \
        --set "env.SERVICE_MYSQL_HOST=${DBHOST}" \
        --set "env.SERVICE_MYSQL_PORT=${DBPORT}" \
        --set "env.SERVICE_MYSQL_USER=${DBUSER}" \
        --set "env.SERVICE_MYSQL_PASS=${DBPASS}" \
        --set "env.CF_ADMIN_USER=admin" \
        --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
        --set "env.CF_DOMAIN=${DOMAIN}" \
        --set "env.CF_CA_CERT=${CF_CA_CERT}" \
        --set "env.UAA_CA_CERT=${UAA_CA_CERT}" \
        --wait
    ```

1. Wait for all the pods to be ready:
    ```bash
    watch kubectl get pods --namespace=${SIDECAR_NAMESPACE}
    ```
    (Press `Ctrl+C` once all the pods are shown as fully ready)

1. Confirm that the service has been added to your CAP installation
    ```bash
    cf marketplace
    ```

## Additional optional configuration

There are additional configuration options that may be used when deploying the MySQL sidecar:

  | Name | Description | Example
  | --- | --- | ---
  | `env.CF_ADMIN_USER` | User name of the CAP administrator account | `admin`
  | `env.SERVICE_TYPE` | The service name (as listed in `cf marketplace`) | `mysql`
  | `kube.registry.hostname` | Docker registry where the MySQL sidecar images are available | `registry.example.com`
  | `kube.organization` | Docker organization where the MySQL sidecar images are available | `library`
  | `kube.registry.username` | Docker registry login information | `AzureDiamond`
  | `kube.registry.password` | Docker registry login information | `hunter2`


## Using the service

To create a new service instance, use the Cloud Foundry command line client as normal:

```bash
cf create-service mysql default my_service_instance_name
```
Where the last argument is the desired name of the service instance.

To bind the service instance to an application, use the `bind-service` subcommand:

```bash
cf bind-service my_application my_service_instance_name
```

# Deploying the PostgreSQL chart

All of the configuration required in the MySQL chart is also required for the PostgreSQL chart; however, the deployment command line is slightly different:

```bash
helm install suse/cf-usb-sidecar-postgres \
    --namespace ${SIDECAR_NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-postgres.${SIDECAR_NAMESPACE}:8081" \
    --set "env.SERVICE_POSTGRESQL_HOST=${DBHOST}" \
    --set "env.SERVICE_POSTGRESQL_PORT=${DBPORT}" \
    --set "env.SERVICE_POSTGRESQL_USER=${DBUSER}" \
    --set "env.SERVICE_POSTGRESQL_PASS=${DBPASS}" \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}" \
    --set "env.SERVICE_POSTGRESQL_SSLMODE=disable" \
    --wait
```

The various database access parameters must point to an existing, externally-managed PostgreSQL instance.  The default port for PostgreSQL is 5432.

Note the additional `env.SERVICE_POSTGRESQL_SSLMODE` configuration; that is used to determine the security when connecting to the PostgreSQL database.  Please see [package pq] for the valid values.

[package pq]: https://godoc.org/github.com/lib/pq

## Additional optional configuration

There are additional configuration options that may be used when deploying the PostgreSQL sidecar:

  | Name | Description | Example
  | --- | --- | ---
  | `env.CF_ADMIN_USER` | User name of the CAP administrator account | `admin`
  | `env.SERVICE_TYPE` | The service name (as listed in `cf marketplace`) | `postgres`
  | `env.SERVICE_POSTGRESQL_SSLMODE` | [SSL configuration] when connecting to the PostgreSQL database | `verify-full`
  | `kube.registry.hostname` | Docker registry where the MySQL sidecar images are available | `registry.example.com`
  | `kube.organization` | Docker organization where the MySQL sidecar images are available | `library`
  | `kube.registry.username` | Docker registry login information | `AzureDiamond`
  | `kube.registry.password` | Docker registry login information | `hunter2`

[SSL configuration]: https://godoc.org/github.com/lib/pq

# Removing service broker sidecar deployments

To correctly remove sidecar deployments, please take the following actions in order:

1. Unbind any applications using instances of the service, and delete those instances
    ```bash
    cf unbind-service my_app my_service_instance
    cf delete-service my_service_instance
    ```

1. Install the [CF-USB CLI plugin] for the [Cloud Foundry CLI]
    ```bash
    cf install-plugin https://github.com/SUSE/cf-usb-plugin/releases/download/1.0.0/cf-plugin-usb-linux-amd64
    ```
    [CF-USB CLI plugin]: https://github.com/SUSE/cf-usb-plugin/
    [Cloud Foundry CLI]: https://github.com/cloudfoundry/cli/

1. Configure the CF-USB CLI plugin
    ```bash
    cf usb target https://usb.${DOMAIN}
    ```

1. Remove the services
    ```bash
    cf usb delete-driver-endpoint "http://cf-usb-sidecar-mysql.${SIDECAR_NAMESPACE}:8081"
    ```
    See `env.SERVICE_LOCATION` configuration value when deploying the helm chart.

1. Delete helm release from Kubernetes
    ```bash
    helm list # Find the name of the helm deployment
    helm delete --purge …
    ```
