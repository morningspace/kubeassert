# KubeAssert

[![Gitter](https://badges.gitter.im/morningspace/community.svg)](https://gitter.im/morningspace/community?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge)
![License](https://img.shields.io/badge/license-MIT-000000.svg)
[![Releases](https://img.shields.io/github/v/release/morningspace/kubeassert.svg)](https://github.com/morningspace/kubeassert/releases)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)

KubeAssert is designed as a kubectl plugin to provide a set of assertions that can be used to quickly assert Kubernetes resources from the command line against your working cluster. It has been submitted to [krew](https://krew.sigs.k8s.io/) as a kubectl plugin distributed on the centralized [krew-index](https://krew.sigs.k8s.io/plugins/). To install KubeAssert using krew:
```shell
kubectl krew install assert
```

To learn more on KubeAssert, please read the online [documentation](https://morningspace.github.io/kubeassert/docs/#/).

![](docs/assets/demo.gif)
