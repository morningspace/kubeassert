## Assert: pod-restarts

Assert pod restarts should not match specified criteria.

### Usage

kubectl assert pod-restarts [options] (-eq|-lt|-gt|-ge|-le VALUE)

### Options

| Option                  | Description
|:------------------------|:-----------
| -eq, -lt, -gt, -ge, -le | Check if the actual value is equal to, less than, greater than, no less than, or no greater than expected value.
| -A, --all-namespaces    | If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
|     --field-selector='' | Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
| -l, --selector=''       | Selector (label query) to filter on, supports '=', '==', and '!='.
| -n, --namespace=''      | If present, the namespace scope for this CLI request.
| -h, --help              | Print the help information.
| -v, --verbose           | Enable the verbose log.
| -V, --version           | Print the version information.

### Examples

To assert restarts of pods less than specified value.
```shell
kubectl assert restarts pods -n default -lt 10
```

To assert restarts of pods with specified label in specified namespace no more than specified value.
```shell
kubectl assert restarts pods -l 'app=echo' -n default -le 10
```

To assert restarts of pods no more than specified value in any namespace.
```shell
kubectl assert restarts pods --all-namespaces -lt 10
```
