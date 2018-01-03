## RC 1

No specific notes.

## Beta 2

The most recent issues I encountered were due to the volume size for the blobstore being too small. This has been fixed in https://github.com/SUSE/scf/pull/1180, but for beta 2 will need the 'blobstore_data' parameter changed from 5 to 50 in the values.yaml.

Additionally, on CaaS Platform v2 this was using the RBAC workaround which creates the following ClusterRoleBindings to the admin ClusterRole, using the following definitions:

```
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: uaa:default
subjects:
- kind: ServiceAccount
  name: default
  namespace: uaa
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: scf:default
subjects:
- kind: ServiceAccount
  name: default
  namespace: scf
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
```

Copy that to a file, e.g. "scf-rbac.yaml" and run

```
$ kubectl create -f scf-rbac.yaml
```

**before** installing CAP-1.0-Beta2.