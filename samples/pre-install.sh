#!/bin/bash

# Make sure CP4MCM namespaces neither exist nor keep terminating
function assert::ns-not-exist-nor-terminating {
  assert::should-not-exist namespace ibm-common-services || assert::should-not-keep-terminating namespace ibm-common-services
  assert::should-not-exist namespace kube-system  || assert::should-not-keep-terminating namespace kube-system 
}

# Make sure no subscription for CP4MCM exists
function assert::sub-not-exist {
  assert::should-not-exist subscriptions.operators.coreos.com -n ibm-common-services
  assert::should-not-exist subscriptions.operators.coreos.com -n kube-system
}

# Make sure no installplan for CP4MCM exists
function assert::ip-not-exist {
  assert::should-not-exist installplans.operators.coreos.com -n ibm-common-services
  assert::should-not-exist installplans.operators.coreos.com -n kube-system
}

# Make sure no clusterserviceversion for CP4MCM exists
function assert::csv-not-exist {
  local excludes="ibm-common-service,ibm-management-orchestrator,operand-deployment-lifecycle-manager"
  assert::should-not-exist clusterserviceversions.operators.coreos.com -n ibm-common-services --excludes $excludes
  assert::should-not-exist clusterserviceversions.operators.coreos.com -n kube-system --excludes $excludes
}

# Make sure no operandrequest for CP4MCM exists
function assert::opreq-not-exist {
  assert::should-not-exist operandrequests.operator.ibm.com -n ibm-common-services
  assert::should-not-exist operandrequests.operator.ibm.com -n cp4m
}

# Make sure no installation for CP4MCM exists
function assert::installation-not-exist {
  assert::should-not-exist installations.orchestrator.management.ibm.com -n cp4m
}

# Make sure no pod exists in CP4MCM namespaces
function assert::pod-not-exist {
  excludes="ibm-common-service-webhook,secretshare"
  assert::should-not-exist pods -n ibm-common-services --excludes $excludes
  assert::should-not-exist pods -n kube-system
  assert::should-not-exist pods -n cp4m
}

# Make sure image pull secret exists in CP4MCM namespaces
function assert::secret-exist {
  assert::should-exist secret ibm-management-pull-secret -n openshift-marketplace
  assert::should-exist secret ibm-management-pull-secret -n cp4m
}

# Make sure image pull secret is added to corresponding service account
function assert::sa-include-image-pull-secret {
  assert::sa-should-include-image-pull-secret default ibm-management-pull-secret -n openshift-marketplace
}

# Make sure CP4MCM catalog source exists in CP4MCM namespaces
function assert::catsrc-exist {
  assert::should-exist catalogsource.operators.coreos.com management-installer-index -n openshift-marketplace
  assert::should-exist catalogsource.operators.coreos.com opencloud-operators -n openshift-marketplace
}

. $(cd $(dirname $0) && pwd)/../lib/utils.sh
. $(cd $(dirname $0) && pwd)/../lib/assert.sh
