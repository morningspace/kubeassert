## num

Assert the number of resource should match specified criteria.

## Usage

kubectl assert num (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options] (-eq|-lt|-gt|-ge|-le VALUE)

## Options

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

## Examples

To assert number of pods in specified namespace equal to specified value.
```shell
kubectl assert num pods -n default -eq 10
```

To assert number of pods in specified namespace less than specified value.
```shell
kubectl assert num pods -n default -lt 11
```

To assert number of pods with specified label in specified namespace no more than specified value.
```shell
kubectl assert num pods -l "app=echo" -n default -le 3
```

To assert number of specified pod greater than specified value.
```shell
kubectl assert num pod echo -n default -gt 0
```
