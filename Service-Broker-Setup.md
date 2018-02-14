# Setting up and using a service broke sidecar

We currently provide helm charts for two service brokers, the
databases `MySQL` and `Postgres`.

This document describes how to use these charts in the context of
`CAP`.

Two cases are presented. First a simple configuration where the chart
activates and uses its own database pod, independent of any other
databases which may in the system. This is followed by a more complex
configuration, where the chart is configured to talk to a pre-existing
database of the user's choice. Both examples will use the service
broker for `mysql`. For `postgres` the overall actions are the
same. The small differences between `mysql` and `postgres` are handled
in a separate section.

# Assumptions of this document

It is assumed that

* The user knows how to get the service broker charts, or has them
  already.

* The user has a functional CAP cluster, running all the necessary CF
  and UAA roles/pods.

* The user has retrieved key `internal-ca-cert` of the UAA secret
  `secret` and stored the base64-decoded result in the environment
  variable `UAA_CA_CERT`.

* The user has retrieved key `internal-ca-cert` of the CF secret
  `secret` and stored the base64-decoded result in the environment
  variable `CF_CA_CERT`.

* The user has chosen the kube namespace for the broker to run in and
  stored it in the environment variable `NAMESPACE`.

  Example: `mysql`

* The user knows the administrative password for the CAP cluster and
  stored it in the environment variable `CLUSTER_ADMIN_PASSWORD`.

* The user knows the publicly visible domain for the CAP cluster and
  stored it in the environment variable `DOMAIN`.

  Example: `cf-dev.io`

# Case 1: Automatic database setup and configuration

Please review the previous section and ensure that all the assumptions
are satisfied.

Further assuming that the helm chart for the service broker is found
at `path/to/mysql` we can deploy the broker via

```
helm install /path/to/mysql \
    --namespace ${NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-mysql.${NAMESPACE}.svc.cluster.local:8081" \
    \
    --set "env.SERVICE_MYSQL_HOST=AUTO" \
    \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}"
```

The first `--set` tells the new broker where itself will be visible on
the internal network of the CAP cluster. During setup this information
will be provided to the USB component of the CAP cluster, so that it
can talk to the new broker.

The next definition tells the broker to create and configure its own
database. Everything is automatic, no user intervention is needed.

The remaining definitions provide the broker with the credentials and
certificates needed to talk to the CAP cluster (USB, UAA, ...)

# Case 2: Talking to an external database

Starting from the helm command of the previous section the definition
of `--set "env.SERVICE_MYSQL_HOST=AUTO"` has to be replaced with a
block of definitions which tell the broker where to find the database
(host and port), and the credentials needed for the database to accept
a connection from the broker (user and password).

With this information stored in the environment variables `DBHOST`,
`DBPORT`, `DBUSER`, and `DBPASSWORD` the command to deploy the broker
becomes

```
helm install /path/to/mysql \
    --namespace ${NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-mysql.${NAMESPACE}.svc.cluster.local:8081" \
    \
    --set "env.SERVICE_MYSQL_HOST=${DBHOST}" \
    --set "env.SERVICE_MYSQL_PORT=${DBPORT}" \
    --set "env.SERVICE_MYSQL_USER=${DBUSER}" \
    --set "env.SERVICE_MYSQL_PASS=${DBPASS}" \
    \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}"
```

Note that the `DBHOST` has to be reachable from inside of the cluster.

# Postgres

For Postgres the overall commands are mainly the same, with
`POSTGRESQL` and `postgres` taking the place of `MYSQL` and `mysql` in
the examples.

Beyond that we have to add the definition
`--set "env.SERVICE_POSTGRESQL_SSLMODE=disable"`
to both examples.

More explicitly:

```
helm install /path/to/postgres \
    --namespace ${NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-postgres.${NAMESPACE}.svc.cluster.local:8081" \
    \
    --set "env.SERVICE_POSTGRESQL_SSLMODE=disable" \
    --set "env.SERVICE_POSTGRESQL_HOST=AUTO" \
    \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}"
```

and

```
helm install /path/to/postgres \
    --namespace ${NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-postgres.${NAMESPACE}.svc.cluster.local:8081" \
    \
    --set "env.SERVICE_POSTGRESQL_SSLMODE=disable" \
    --set "env.SERVICE_POSTGRESQL_HOST=${DBHOST}" \
    --set "env.SERVICE_POSTGRESQL_PORT=${DBPORT}" \
    --set "env.SERVICE_POSTGRESQL_USER=${DBUSER}" \
    --set "env.SERVICE_POSTGRESQL_PASS=${DBPASS}" \
    \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}"
```
