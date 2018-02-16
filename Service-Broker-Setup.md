# Setting up and using a service broke sidecar

We currently provide helm charts for two service brokers managing
access to `MySQL` and `Postgres` databases.

This document describes how to use these charts in the context of
a CAP cluster.

While the document's examples focus on deploying a `MySQL` database
the steps are virtually identical for `Postgres`. The
[Postgres](#appendix-i-postgres) appendix describes the
differences.

The second appendix lists all relevant chart variables and their
meanings.

# Assumptions of this document

## About the chart to be deployed

* The user knows how to get the service broker charts, or has them
  already. This also implies that the user knows the location of the
  charts in the filesystem.

* The user has stored the path to the chart in the environment
  variable `CHART`.

  ```
  CHART=/path/to/mysql-chart
  ```

* The user has chosen the kube namespace for the broker to run in and
  stored it in the environment variable `NAMESPACE`.

  ```
  NAMESPACE=mysql
  ```

* The user knows docker repository and organization in that repository
  for the docker images needed by the chart(s) and stored them in the
  environment variables `DOCKER_ORGANIZATION` and `DOCKER_REPOSITORY`.

  ```
  DOCKER_REPOSITORY=docker.io
  DOCKER_ORGANIZATION=splatform
  ```

  If the repository requires authentication the user has logged into it.

  ```
  docker login ...
  ```

## About the cluster to deploy the chart on.

* The user has a functional CAP cluster, running all the necessary CF
  and UAA roles/pods.

## About the database to talk to

The users knows the publicly reachable name of the host the database
to talk to lives on. The user further knows the port on that host the
database listens on, and the credentials (user and password) needed
for the database to accept connections on the port. All this
information is stored in the environment variables `DBHOST`, `DBPORT`,
`DBUSER`, and `DBPASSWORD`.

```
DBHOST=mysql-host.in.some.domain
DBPORT=3306
DBUSER=root
DBPASS=the-mysql-password
```

# Deploying the chart in three steps

Please review the previous section and ensure that all the assumptions
are satisfied.

## CAP location and namespaces

Determine the namespaces used for the CF and UAA roles in the CAP
cluster and store them in the environment variables `CF_NAMESPACE` and
`UAA_NAMESPACE`. Further determine the publicly visible domain for the
CAP cluster and store it in the environment variable `DOMAIN`.

```
CF_NAMESPACE=cf
UAA_NAMESPACE=uaa
DOMAIN=cf-dev.io
```

## CAP certs and credentials

Retrieve key `internal-ca-cert` of the UAA secret `secret` and store
the base64-decoded result in the environment variable `UAA_CA_CERT`.

```
UAA_CA_CERT="$(kubectl get secret secret --namespace ${UAA_NAMESPACE} -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"
```

Retrieve key `internal-ca-cert` of the CF secret `secret` and store
the base64-decoded result in the environment variable `CF_CA_CERT`.

```
CF_CA_CERT="$(kubectl get secret secret --namespace ${CF_NAMESPACE} -o jsonpath="{.data['internal-ca-cert']}" | base64 --decode -)"
```

Retrieve the administrative password for the CAP cluster and store it
in the environment variable `CLUSTER_ADMIN_PASSWORD`.

```
CLUSTER_ADMIN_PASSWORD="$(kubectl get secret secret --namespace ${CF_NAMESPACE} -o jsonpath="{.data['cluster-admin-password']}" | base64 --decode -)"
```

## Deployment

We can now deploy the broker's chart via

```
helm install ${CHART} \
    --namespace ${NAMESPACE} \
    --set "env.SERVICE_LOCATION=http://cf-usb-sidecar-mysql.${NAMESPACE}.svc.cluster.local:8081" \
    \
    --set "env.SERVICE_MYSQL_HOST=${DBHOST}" \
    --set "env.SERVICE_MYSQL_PORT=${DBPORT}" \
    --set "env.SERVICE_MYSQL_USER=${DBUSER}" \
    --set "env.SERVICE_MYSQL_PASS=${DBPASS}" \
    \
    --set "env.CF_ADMIN_USER=admin" \
    --set "env.CF_ADMIN_PASSWORD=${CLUSTER_ADMIN_PASSWORD}" \
    --set "env.CF_DOMAIN=${DOMAIN}" \
    --set "env.CF_CA_CERT=${CF_CA_CERT}" \
    --set "env.UAA_CA_CERT=${UAA_CA_CERT}" \
    \
    --set "kube.organization=${DOCKER_ORGANIZATION}" \
    --set "kube.registry.hostname=${DOCKER_REPOSITORY}"
```

Notes: 

* The first `--set` tells the new broker where itself will be visible
  on the internal network of the CAP cluster. Its setup errand
  provides this information to the USB component of the CAP cluster,
  so that it can talk to the new broker.

* The remaining assignments provide the connection information for the
  database and CAP to the broker, as well as the origin information
  for the docker images referenced by the chart.


# Appendix I: Postgres

Deploying the postgres broker and chart is virtually identical to
deploying mysql. The only differences are:

* The chart variables have prefix `SERVICE_POSTGRESQL_` instead of
  `SERVICE_MYSQL_`.

* The `SERVICE_LOCATION uses `cf-usb-sidecar-postgres`.

* An additional assignment of the form
  `--set "env.SERVICE_POSTGRESQL_SSLMODE=disable"` may be required,
  depending on the setup of the database. See also
  [Appendix II: Chart variables](#appendix-ii-chart-variables) for
  more information on the available values.

# Appendix II: Chart variables

|Variable			|Meaning|
|---				|---|
|env.SERVICE_LOCATION		|Broker location as seen by CAP cluster|
|env.SERVICE_(db)_HOST		|Host the database lives on|
|env.SERVICE_(db)_PORT		|Port the database listens on|
|env.SERVICE_(db)_USER		|User name for database connections|
|env.SERVICE_(db)_PASS		|Password for database connections|
|env.SERVICE_POSTGRESQL_SSLMODE	|Connection mode to postgres server. See [Package PQ](https://godoc.org/github.com/lib/pq) for details|
|env.CF_ADMIN_USER		|User name of the CAP cluster admin|
|env.CF_ADMIN_PASSWORD		|Admin password for the CAP cluster|
|env.CF_DOMAIN			|Public domain of the CAP cluster|
|env.CF_CA_CERT			|CA cert for talking to the CF components of the cluster|
|env.UAA_CA_CERT		|CA cert for talking to the UAA components of the cluster|
|kube.organization		|Docker organization to the repository below|
|kube.registry.hostname		|Docker repository holding the chart's docker images|

where `(db)` is either `MYSQL` or `POSTGRESQL`.
