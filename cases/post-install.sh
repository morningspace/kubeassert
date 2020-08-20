#!/bin/bash

# Make sure CP4MCM namespaces exist and do not keep terminating
function assert::ns-exist-not-terminating {
  assert::should-exist namespace ibm-common-services && assert::should-not-keep-terminating namespace ibm-common-services
  assert::should-exist namespace kube-system && assert::should-not-keep-terminating namespace kube-system
}

# Make sure all configmaps and secrets are copied to target namespaces
function assert::secretshare-working {
  assert::secretshare-should-be-cloned configmap
  assert::secretshare-should-be-cloned secret
}

# Make sure pods for OLM and ODLM are running
function assert::pod-running-for-olm-and-odlm {
  assert::pod-status -n openshift-operators -l name=operand-deployment-lifecycle-manager

  assert::pod-status -n openshift-marketplace -l olm.catalogSource=management-installer-index
  assert::pod-status -n openshift-marketplace -l olm.catalogSource=opencloud-operators

  assert::pod-status -n openshift-operator-lifecycle-manager -l app=olm-operator
}

# Make sure pods for CP4MCM operators are running
function assert::pod-running-for-operators {
  assert::pod-status -n openshift-operators -l name=ibm-common-service-operator
  assert::pod-status -n openshift-operators -l name=ibm-management-orchestrator
}

# Make sure critical pods are running in ibm-common-services namespace
function assert::pod-running-for-cs {
  assert::pod-status -n ibm-common-services -l app=auth-idp
  assert::pod-status -n ibm-common-services -l app=auth-pap
  assert::pod-status -n ibm-common-services -l app=auth-pdp
  assert::pod-status -n ibm-common-services -l app=icp-mongodb
  assert::pod-status -n ibm-common-services -l app=ibm-cert-manager-controller
  assert::pod-status -n ibm-common-services -l app=management-ingress
}

. $(cd $(dirname $0) && pwd)/../lib/utils.sh
. $(cd $(dirname $0) && pwd)/../lib/assert.sh
