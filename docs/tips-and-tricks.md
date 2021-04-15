## Tips and Tricks

### Using Multiple Label and Field Selectors

When use assertion such as `exist` or `not-exist` to validate the existence of Kubernetes resource, you can use label selector and/or field selector to filter on the query results returned from the cluster that you are working with. For example, to assert pod with label `app` equal to `echo` running in `default` namespace, you can use below assertion that specifies both the label selector and the field selector:
```shell
kubectl assert exist pods -l app=echo --field-selector status.phase=Running -n default
```

You can also use multiple label selectors and field selectors in the same assertion as needed. For example, to assert the running pods that have multiple lables in a namespace, you can write the assertion as below:
```shell
kubectl assert exist pods -l app=echo -l component=proxy \
  --field-selector metadata.namespace==default --field-selector status.phase=Running \
  --all-namespaces
```

Alternatively, you can also use comma separated list to specify multiple requirements using a single `-l` or `--field-selector` option. For example, the below assertion has the same effect as above one but is more compact:
```shell
kubectl assert exist pods -l app=echo,component=proxy \
  --field-selector metadata.namespace==default,status.phase=Running \
  --all-namespaces
```

### Using Enhanced Field Selector

When assert the existence of Kubernetes resource using `exist` or `not-exist` assertion, although it allows you to filter on query results by specifying field selector, the support of field selector is very limited. This is because both `exist` and `not-exist` use `kubectl get` to query the resource underneath and directly use the native `--field-selector` option provided by `kubectl`. But according to Kubernetes documentation, filtering by fields actually happens on server side, and the server only supports a limited number of field queries per type. For example, when assert pods, we can query by some fields under `status` using field selector. But this will not work for deployments:
```shell
kubectl assert exist deployments -l app=echo --field-selector status.replicas=1
ASSERT deployments matching label criteria 'app=echo' and field criteria 'status.replicas=1' should exist.
Error from server (BadRequest): Unable to find "extensions/v1beta1, Resource=deployments" that match label selector "app=echo", field selector "status.replicas=1": "status.replicas" is not a known field selector: only "metadata.name", "metadata.namespace"
ASSERT FAIL Error getting resource(s).
```

Because of this, there are two additional assertions, `exist-enhanced` and `not-exist-enhanced`, which provide the same functionality but with enhanced field selector support. So, the above assertion can be modified as below:
```shell
kubectl assert exist-enhanced deployments -l app=echo --field-selector status.replicas=1
ASSERT deployments matching label criteria 'app=echo' and field criteria 'status.replicas=1' should exist.
INFO   Found 1 resource(s).
NAME   NAMESPACE   COL0
echo   default     1
ASSERT PASS
```

The native field selector supports operator `=`, `==`, and `!=` (`=` and `==` mean the same thing), while the enhanced field selector even supports regular expression match using `=~`. This makes it much more flexible and powerful when you define the field selector. Here are some examples:

To assert service accounts in `default` namespace should include a specified secret:
```shell
kubectl assert exist-enhanced serviceaccounts --field-selector 'secrets[*].name=~my-secret' -n default
```

To assert a custom resource at least has one `condition` element under `status` where the value of `type` field should be `Deployed`:
```shell
kubectl assert exist-enhanced MyResources --field-selector 'status.conditions[*].type=~Deployed'
```

To assert a custom resource where all instances names for this type of resource should start with text that falls into a specified list:
```shell
kubectl assert exist-enhanced MyResource --field-selector metadata.name=~'foo.*|bar.*|baz.*'
```

### Validate Pods Status

Although it is possible to assert pods status using assertion `exist`, `not-exist`, `exist-enhanced`, and `not-exist-enhanced`, it can be complicated when you try to write the assertion for this in one line.

For convenience, there are a few assertions whose names start with `pod-` can be used to validate the pods status in a more effective way:
* Use `pod-ready` to validate the pod readiness.
* Use `pod-restarts` to validate the pod restarts count.
* Use `pod-not-terminating` to validate no pod keeps terminating.

Here are some examples. To assert all pods should be ready in a specified namespace or all namespaces:
```shell
kubectl assert pod-ready pods -n default
kubectl assert pod-ready pods --all-namespaces
```

To assert there is no pod that keeps terminating in a specified namespace or any namespace:
```shell
kubectl assert pod-not-terminating -n default
kubectl assert pod-not-terminating --all-namespaces
```

To assert the restarts of all pods in a specified namespace or all namespaces should be less than an expected value:
```shell
kubectl assert pod-restarts -lt 10 -n default
kubectl assert pod-restarts -lt 10 --all-namespaces
```

### Detecting Objects Keep Terminating

The `pod-not-terminating` assertion can be used to detect pod that keeps terminating. However, it is not just the pod can be in such a situation. If you want to detect this for object other than pod, you can use `exist-enhanced`, `not-exist-enhanced`, or write your own.

As an example, to assert a custom resource where there is no instance that keeps terminating in any namespace, we can check if it has `deletionTimestamp` metadata and the `status.phase` field is `Running`. When a resource gets deleted, a `deletionTimestamp` will be added as its metadata. If a resource is deleted but still running, this might be an instance that keeps terminating:
```shell
kubectl assert not-exist-enhanced MyResources --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running --all-namespaces
```

As another example, to assert there is no namespace that keeps terminating in the cluster, we can check both `deletetionTimestamp` and `finalizers`. If a namespace has both, it is very likely that this namespace is keeping terminating, because Kubernetes will not delete the namespace so long as there is any finalizer attached.
```shell
kubectl assert not-exist-enhanced namespace --field-selector metadata.deletetionTimestamp!='<none>',spec.finalizers[*]!='<none>'
```
