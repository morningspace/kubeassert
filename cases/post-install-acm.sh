#!/bin/bash

# Make sure RHACM namespaces exist and do not keep terminating
function assert::ns-exist-not-terminating {
  assert::should-exist namespace open-cluster-management && assert::should-not-keep-terminating namespace open-cluster-management
  assert::should-exist namespace open-cluster-management-hub && assert::should-not-keep-terminating namespace open-cluster-management-hub
  assert::should-exist namespace hive && assert::should-not-keep-terminating namespace hive
}

# Make sure RHACM CRDs are defined
function assert::crd-exist {
  assert::should-exist customresourcedefinition.apiextensions.k8s.io helmreleases.apps.open-cluster-management.io
}

# Make sure all helmreleases are created
function assert::helmrelease-created {
  local includes="application-chart,cert-manager,cert-manager-webhook,configmap-watcher,console-chart,grc,kui-web-terminal,management-ingress,rcm,search-prod,topology"
  assert::should-exist helmrelease.apps.open-cluster-management.io --includes $includes -n open-cluster-management
}

# Make sure all helmreleases are installed
function assert::helmrelease-installed {
  assert::helmrelease-should-be-installed -n open-cluster-management
}

# Make sure the number of running pods for RHACM is no less than 55
function assert::pod-num-no-less-than-55 {
  assert::pod-num no_less_than 55 -n open-cluster-management
}

# Make sure RHACM CRs are created
function assert::cr-exist {
  assert::should-exist multiclusterhub.operator.open-cluster-management.io multiclusterhub -n open-cluster-management
  assert::should-exist clustermanager.operator.open-cluster-management.io cluster-manager
}

# Make sure all API services are available
function assert::api-service-available {
  assert::api-service-should-be-available
}

. $(cd $(dirname $0) && pwd)/../lib/utils.sh
. $(cd $(dirname $0) && pwd)/../lib/assert.sh
