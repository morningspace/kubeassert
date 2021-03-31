## Assert: exist-enhanced

Assert resource should exist using enhanced field selector.

### Usage

kubectl assert exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]

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

To assert pods in running status exist in current namespace.
```shell
kubectl assert exist-enhanced pods --field-selector status.phase=Running
```

To assert pods with specified label in running status exist.
```shell
kubectl assert exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Running
```

To assert pods being deleted exist in some namespaces.
```shell
kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' --all-namespaces
```

To assert pods being deleted keeping running exist in some namespaces.
```shell
kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running --all-namespaces
```

To assert deployments have specified replicas ready.
```shell
kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 -n default
kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 --field-selector metadata.namespace=default --all-namespaces
```

To assert deployments with specified label have specified replicas ready.
```shell
kubectl assert exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=1
```

To assert service accounts with specified secret exist using regex.
```shell
kubectl assert exist-enhanced serviceaccounts --field-selector secrets[*].name=~my-secret -n default
```

To assert MyResources with specified status exist using regex.
```shell
kubectl assert exist-enhanced MyResources --field-selector status.conditions[*].type=~Deployed -n default
```

To assert MyResources with their names in a specified list exist using regex.
```shell
kubectl assert exist-enhanced MyResource --field-selector metadata.name=~'foo.*|bar.*|baz.*' -n default
```