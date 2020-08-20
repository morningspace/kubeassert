#!/bin/bash

# Make sure RHACM namespaces neither exist nor keep terminating
function assert::ns-not-exist-nor-terminating {
  assert::should-not-exist namespace open-cluster-management || assert::should-not-keep-terminating namespace open-cluster-management
  assert::should-not-exist namespace open-cluster-management-hub || assert::should-not-keep-terminating namespace open-cluster-management-hub
  assert::should-not-exist namespace hive || assert::should-not-keep-terminating namespace hive
}

# Make sure no pod exists in RHACM namespaces
function assert::pod-not-exist {
  assert::should-not-exist pods -n open-cluster-management
  assert::should-not-exist pods -n open-cluster-management-hub
  assert::should-not-exist pods -n hive
}

# Make sure no RHACM custom resource exists
function assert::cr-not-exist {
  local crd_multiclusterhubs="multiclusterhubs.operator.open-cluster-management.io"
  assert::should-not-exist $crd_multiclusterhubs multiclusterhub -n open-cluster-management ||
  assert::should-not-keep-terminating $crd_multiclusterhubs multiclusterhub -n open-cluster-management

  local crd_clustermanagers="clustermanagers.operator.open-cluster-management.io"
  assert::should-not-exist $crd_clustermanagers cluster-manager ||
  assert::should-not-keep-terminating $crd_clustermanagers cluster-manager

  local crd_manifestworks="manifestworks.work.open-cluster-management.io"
  assert::should-not-exist $crd_manifestworks --all-namespaces ||
  assert::should-not-keep-terminating $crd_manifestworks --all-namespaces

  local crd_klusterletaddonconfigs="klusterletaddonconfigs.agent.open-cluster-management.io"
  assert::should-not-exist $crd_klusterletaddonconfigs --all-namespaces ||
  assert::should-not-keep-terminating $crd_klusterletaddonconfigs --all-namespaces

  local crd_managedclusters="managedclusters.cluster.open-cluster-management.io"
  assert::should-not-exist $crd_managedclusters --all-namespaces ||
  assert::should-not-keep-terminating $crd_managedclusters --all-namespaces

  local crd_managedclusterinfos="managedclusterinfos.cluster.open-cluster-management.io"
  assert::should-not-exist $crd_managedclusterinfos --all-namespaces ||
  assert::should-not-keep-terminating $crd_managedclusterinfos --all-namespaces
}

# Make sure no helmreleases exists
function assert::helmrelease-not-exist {
  assert::should-not-exist helmreleases.apps.open-cluster-management.io -n open-cluster-management ||
  assert::helmrelease-should-be-deletable -n open-cluster-management
}

# Make sure all API services are available
function assert::api-service-available {
  assert::api-service-should-be-available
}

. $(cd $(dirname $0) && pwd)/../lib/utils.sh
. $(cd $(dirname $0) && pwd)/../lib/assert.sh
