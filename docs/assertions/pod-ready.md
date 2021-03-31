## Assert: pod-ready

Assert pod should be ready.

### Usage

kubectl assert pod-ready [options]

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

To assert pods ready in specified namespace.
```shell
kubectl assert pod-ready pods -n default
```

To assert pods ready in all namespaces.
```shell
kubectl assert pod-ready pods --all-namespaces
```