## Getting Started

### Install and run

It is easy to install Kube Assert since it is just a single script. You can download it from the Kube Assert git repository then make it executable as below:
```shell
curl -L https://raw.githubusercontent.com/morningspace/kube-assert/master/kubectl-assert.sh -o kubectl-assert
chmod +x kubectl-assert
```

To validate the installation, run the script:
```shell
./kubectl-assert
```

You will see the general help information and a list of assertions that are supported by Kube Assert out of the box. Run the script with a specified assertion along with `--help` option, you will see more information on how to use each assertion. For example:
```shell
./kubectl-assert exist --help
```

### Run as kubectl plugin

Although Kube Assert can be run as a standalone command from the command line, it is recommended to run it as [kubectl plugin](https://kubernetes.io/docs/tasks/extend-kubectl/kubectl-plugins/) since it is the most intuitive way to run Kube Assert given you are quite familiar with the use of `kubectl`.

To run Kube Assert as a kubectl plugin, the only thing you need to do is to place the script anywhere in your `PATH`. For example:
```shell
mv ./kubectl-assert /usr/local/bin
```

You may now invoke Kube Assert as a kubectl command:
```shell
kubectl assert
```

This will give you exactly the same output as above when you run the script in standalone mode.

To learn what assertions that Kube Assert supports out of the box, please read [Assertions](assertions.md).
