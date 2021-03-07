## What is KubeAssert

KubeAssert is designed as a kubectl plugin to provide a set of assertions that can be used to quickly assert Kubernetes resources from the command line against your working cluster.

Using KubeAssert can help you validate the cluster status, application installation, deployment healthiness, or trouble shoot the problems existed in your cluster. For example, you can validate if resource should or should not exist in the cluster, if the status of the resource should or should not include an expected value, if the instance number of the resource should be less than or no more than an expected value, and so on and so forth.

KubeAssert can be run as a standalone command from the command line since essentially it is just a script. But it can also be installed as a [kubectl plugin](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/) so that you can run KubeAssert just as normal `kubectl <command>`. As an example, to verify if there is any pod with `app` label equal to `echo` existed in `default` namespace, you can run below command:
```shell
kubectl assert exist pods -l app=echo -n default
```

A set of assertions can be put into a script, which can be integrated into CI/CD pipeline as part of the automated verification test to your cluster.

To learn more on how to install and run KubeAssert, please read [Getting Started](getting-started.md).
