## What is Kube Assert

Kube Assert is designed as a set of assertions that can be used to quicly assert Kubernetes resources from the command line against your working cluster.

Using Kube Assert can help you verify the cluster status, application installation, deployment healthiness, or trouble shoot the problems existed in your cluster. For example, you can verify if a certain resource should or should not exist in the cluster, if the status of the resource should or should not include an expected value, if the instance number of the resource should be less than or no more than an expected value, and so on and so forth.

Kube Assert can be run as a standalone command from the command line since essentially it is just a script. But it can also be installed as a [kubectl plugin](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/) so that you can run Kube Assert just as a normal `kubectl <command>` command. As an example, to verify if there is any pod with `app` label equal to `echo` existed in `default` namespace, you can run below command:
```shell
kubectl assert exist pods -l app=echo -n default
```

A set of Kube Assert commands can be put into a script, which can be integrated into CI/CD pipeline as part of the automated verification test to your cluster.

To learn more on how to install and run Kube Assert, please read [Getting Started](getting-started.md).
