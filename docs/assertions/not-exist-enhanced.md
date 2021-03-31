## Assert: not-exist-enhanced

Assert resource should not exist using enhanced field selector.

### Usage

kubectl assert not-exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]

### Options

| Option                  | Description
|:------------------------|:-----------
| -A, --all-namespaces    | If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
|     --field-selector='' | Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
| -l, --selector=''       | Selector (label query) to filter on, supports '=', '==', and '!='.
| -n, --namespace=''      | If present, the namespace scope for this CLI request.
| -h, --help              | Print the help information.
| -v, --verbose           | Enable the verbose log.
| -V, --version           | Print the version information.


### Examples

To assert pods in error status not exist in current namespace.
```shell
kubectl assert not-exist-enhanced pods --field-selector status.phase=Error
```

To assert pods with specified label in error status not exist.
```shell
kubectl assert not-exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Error
```

To assert pods being deleted not exist in any namespace.
```shell
kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' --all-namespaces
```

To assert pods being deleted keeping running not exist in some namespaces.
```shell
kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running --all-namespaces
```

To assert deployments have replicas not ready.
```shell
kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=0 -n default
kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=0 --field-selector metadata.namespace=default --all-namespaces
```

To assert deployments with specified label have replicas not ready.
```shell
kubectl assert not-exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=0
```

To assert namespace keeps terminating not exist.
```shell
kubectl assert not-exist-enhanced namespace --field-selector metadata.deletetionTimestamp!='<none>',spec.finalizers[*]!='<none>'
```