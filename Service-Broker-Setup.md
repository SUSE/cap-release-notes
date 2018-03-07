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
- External databases must be reachable from the running applications; please
  refer to [application security groups] for details.

[helm docs]: https://docs.helm.sh/using_helm/#quickstart
[application security groups]: http://docs.cloudfoundry.org/concepts/asg.html

# Deploying the MySQL chart

You need an external MySQL installation, with account credentials that allow creating and deleting both databases and users.

## Configuring the deployment

Create a values.yaml file (the rest of the document assumes it is called `usb-config-values.yaml`) with the settings required for the install.  Use the file below as a template, and modify the values to suit your installation.

```yaml
env:
  # Database access credentials; the given user must have privileges to create
  # delete both databases and users
  SERVICE_MYSQL_HOST: mysql.example.com
  SERVICE_MYSQL_PORT: 3306
  SERVICE_MYSQL_USER: AzureDiamond
  SERVICE_MYSQL_PASS: hunter2

  # CAP access credentials
  CF_ADMIN_USER: admin
  CF_ADMIN_PASSWORD: changeme
  CF_DOMAIN: example.com

  # CAP internal certificate authorities
  # CF_CA_CERT can be obtained via the command line:
  #   kubectl get secret -n $NAMESPACE secret-$REVISION -o jsonpath='{.data.internal-ca-cert}' | base64 -d
  # Where $NAMESPACE is the namespace CAP was deployed in, and $REVISION is the helm revision number
  CF_CA_CERT: |
    -----BEGIN CERTIFICATE-----
    MIIESGVsbG8gdGhlcmUgdGhlcmUgaXMgbm8gc2VjcmV0IG1lc3NhZ2UsIHNvcnJ5Cg==
    -----END CERTIFICATE-----

  # UAA_CA_CERT can be obtained with the command line:
  #   kubectl get secret -n $NAMESPACE secret-$REVISION -o jsonpath='{.data.uaa-ca-cert}' | base64 -d
  UAA_CA_CERT:|
    -----BEGIN CERTIFICATE-----
    MIIETm8gcmVhbGx5IEkgc2FpZCB0aGVyZSBpcyBubyBzZWNyZXQgbWVzc2FnZSEhCg==
    -----END CERTIFICATE-----

  SERVICE_TYPE: mysql # Optional

# The whole "kube" section is optional
kube:
  organization: library # Docker registry organization
  registry:             # Docker registry access configuration
    hostname: registry.example.com
    username: AzureDiamond
    password: hunter2
```

## Deploy the chart

When deploying the chart, a Kubernetes namespace to install the sidecar to is
required.  It may optionally be the same namespace as CAP is installed to,
though only one MySQL service may be deployed into a namespace at a time.

1. Ensure that you have the SUSE helm chart repository available:
    ```bash
    helm repo add suse https://kubernetes-charts.suse.com/
    ```

1. Install the helm chart:
    ```bash
    SIDECAR_NAMESPACE=my_sidecar
    helm install suse/cf-usb-sidecar-mysql \
        --namespace ${SIDECAR_NAMESPACE} \
        --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-mysql.${SIDECAR_NAMESPACE}:8081" \
        --values usb-config-values.yaml \
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

The PostgreSQL configuration is slightly different from the MySQL configuration;
the database-specific keys are named differently, and an additional key is
introduced:

```yaml
env:
  # Database access credentials; the given user must have privileges to create
  # delete both databases and users
  SERVICE_POSTGRESQL_HOST: postgres.example.com
  SERVICE_POSTGRESQL_PORT: 5432
  SERVICE_POSTGRESQL_USER: AzureDiamond
  SERVICE_POSTGRESQL_PASS: hunter2
  # The SSL connection mode when connecting to the database.  For a list of
  # valid values, please see https://godoc.org/github.com/lib/pq
  SERVICE_POSTGRESQL_SSLMODE: disable

  # CAP access credentials
  CF_ADMIN_USER: admin
  CF_ADMIN_PASSWORD: changeme
  CF_DOMAIN: example.com

  # CAP internal certificate authorities
  # CF_CA_CERT can be obtained via the command line:
  #   kubectl get secret -n $NAMESPACE secret-$REVISION -o jsonpath='{.data.internal-ca-cert}' | base64 -d
  # Where $NAMESPACE is the namespace CAP was deployed in, and $REVISION is the helm revision number
  CF_CA_CERT: |
    -----BEGIN CERTIFICATE-----
    MIIESGVsbG8gdGhlcmUgdGhlcmUgaXMgbm8gc2VjcmV0IG1lc3NhZ2UsIHNvcnJ5Cg==
    -----END CERTIFICATE-----

  # UAA_CA_CERT can be obtained with the command line:
  #   kubectl get secret -n $NAMESPACE secret-$REVISION -o jsonpath='{.data.uaa-ca-cert}' | base64 -d
  UAA_CA_CERT:|
    -----BEGIN CERTIFICATE-----
    MIIETm8gcmVhbGx5IEkgc2FpZCB0aGVyZSBpcyBubyBzZWNyZXQgbWVzc2FnZSEhCg==
    -----END CERTIFICATE-----

  SERVICE_TYPE: postgres # Optional

# The whole "kube" section is optional
kube:
  organization: library # Docker registry organization
  registry:             # Docker registry access configuration
    hostname: registry.example.com
    username: AzureDiamond
    password: hunter2
```

The command to install the helm chart is also different in having a different
host name for the service location:

```bash
SIDECAR_NAMESPACE=psql_sidecar
helm install suse/cf-usb-sidecar-postgres \
    --namespace ${SIDECAR_NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-postgres.${SIDECAR_NAMESPACE}:8081" \
    --values usb-config-values.yaml \
    --wait
```

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
