## exist

Assert resource should exist.

## Usage

kubectl assert exist (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]

## Options

| Option                  | Description
|:------------------------|:-----------
| -A, --all-namespaces    | If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
|     --field-selector='' | Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
| -l, --selector=''       | Selector (label query) to filter on, supports '=', '==', and '!='.
| -n, --namespace=''      | If present, the namespace scope for this CLI request.
| -h, --help              | Print the help information.
| -v, --verbose           | Enable the verbose log.
| -V, --version           | Print the version information.

## Examples

To assert resources exist in current namespace.
```shell
kubectl assert exist pods
```

To assert resources exist in specified namespace.
```shell
kubectl assert exist replicasets -n default
```

To assert specified resource exists.
```shell
kubectl assert exist deployment echo -n default
```

To assert resources with specified label exist.
```shell
kubectl assert exist pods -l 'app=echo' -n default
```

To assert resources with specified field selector exist.
```shell
kubectl assert exist pods --field-selector 'status.phase=Running' -n default
```

To assert resources with specified label and field selector exist.
```shell
kubectl assert exist pods -l 'app=echo' --field-selector 'status.phase=Running' -n default
```

To assert resources with multiple specified lables and field selectors exist in some namespaces.
```shell
kubectl assert exist deployment,pod -l 'app=echo,component=echo' --field-selector 'metadata.namespace==default' --all-namespaces
```