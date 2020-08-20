#!/bin/bash

function get_fix_methods_info {
  FIX_METHODS_INFO=()
  local methods=($(cat $0 | grep "^function fix::.* {$" | awk '{print $2}'))
  for (( i = 0; i < ${#methods[@]}; i ++ )); do
    local method_name="${methods[$i]}"
    local method_description="$(cat $0 | grep "^function $method_name {$" -B1 | sed '2d')"
    FIX_METHODS_INFO+=("${method_name}|${method_description}")
  done
}

function list_fix_methods {
  echo "Fixes:"

  get_fix_methods_info

  for method_info in "${FIX_METHODS_INFO[@]}"; do
    local method_name="${method_info%|*}"
    local method_description="${method_info#*|}"
    printf "  %-36s %s\n" "${method_name#fix::}" "${method_description#\# }"
  done
}

function fix {
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local method="list_fix_methods"
  [[ -n ${POSITIONAL[0]} ]] && method="fix::${POSITIONAL[0]}"
  
  if type $method &>/dev/null ; then
    $method "${POSITIONAL[@]:1}"
  else
    logger::warn "Unknown command: $method"
    list_fix_methods
  fi
}

# Delete all unavailable api services
function fix::rm-bad-api-svc {
  logger::info "Detecting api services that are unavailable ... "
  local services=($(oc get apiservices | grep False | awk '{print $1}'))
  if [[ -n ${services[@]} ]]; then
    local num=${#services[@]}
    local num_deleted=0

    logger::info "Found $num unavailable api service(s)."
    for service in ${services[@]}; do
      logger::info "Deleting $service ..."
      oc delete apiservice $service && (( num_deleted++ ))
    done

    logger::info "$num_deleted resource(s) deleted."
  else
    logger::info "No unavailable api service found."
  fi
}

# Restart the pods corresponding to an api service
function fix::restart-pod-for-api-svc {
  local apiservice=$1
  local resource_resp=$(oc get apiservices $apiservice -o json)
  local service=$(echo $resource_resp | jq -r .spec.service.name)
  local namespace=$(echo $resource_resp | jq -r .spec.service.namespace)

  if [[ -n $service && -n $namespace ]]; then
    logger::info "Found $service service corresponding to $apiservice in $namespace namespace."

    local service_resp="$(oc get service $service -n $namespace -o json)"
    local labels=($(echo $service_resp | jq -r '.spec | select(.selector != null) | .selector | to_entries[] | "\(.key)=\(.value)"'))
    if [[ -n ${labels[@]} ]]; then
      local labels_text=$(IFS=',' ; echo "${labels[*]}")
      local pods=($(oc get pod -l "$labels_text" -n $namespace -o name))
      if [[ -n ${pods[@]} ]]; then
        logger::info "Found pods corresponding to $service service in $namespace namespace."
        logger::info "Deleting them to trigger restart ..."
        for pod in ${pods[@]}; do
          fix::rm-rs $pod -n $namespace
        done
      fi
    fi
  fi
}

# Delete namespace that keeps terminating
function fix::rm-ns {
  local namespace=$1
  local apiserver=$(oc config view --minify -ojson | jq -r .clusters[].cluster.server)
  oc get ns $namespace -o json > $HOME/.cp4mcm/$namespace.json
  cat $HOME/.cp4mcm/$namespace.json | jq '.spec.finalizers=[]' | \
    curl -k -H "Content-Type: application/json" -H "Authorization: Bearer $(oc whoami -t)" -X PUT --data-binary @- $apiserver/api/v1/namespaces/$namespace/finalize
}

# List namespace-scoped api resources for a particular namespace
function fix::ls-api-rs-in-ns {
  local namespace
  local delete
  local excludes=("packagemanifest")
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; POSITIONAL+=("$1" "$2"); shift 2 ;;
    -d|--delete)
      delete=1; shift ;;
    *)
      POSITIONAL+=("$1"); shift;;
    esac
  done

  logger::info "Collecting api resources ..."

  local resource_types=($(oc api-resources --verbs=list --namespaced -o name))
  local num_rt=${#resource_types[@]}

  logger::info "Found $num_rt api resources."

  for (( i = 0; i < $num_rt; i ++ )); do
    local resource_type=${resource_types[$i]}

    logger::info "$i) Looking for $resource_type in $namespace namespace ..."

    local resources=($(oc get $resource_type -n $namespace -o name))
    local num=${#resources[@]}
    local num_deleted=0

    if [[ $num != 0 ]]; then
      logger::info "Found $num instance(s) of $resource_type in $namespace namespace."

      if [[ $delete != 1 ]]; then
        oc get $resource_type -n $namespace
      else
        for resource in ${resources[@]}; do
          local is_excluded=0
          for exclude in ${excludes[@]}; do
            [[ $resource =~ $exclude ]] && is_excluded=1 && break
          done

          if [[ $is_excluded == 0 ]]; then
            fix::rm-rs $resource ${POSITIONAL[@]}; (( num_deleted++ ))
          else
            logger::info "Resource $resource is excluded."
          fi
        done

        logger::info "$num_deleted instance(s) of $resource_type deleted."
      fi
    fi
  done
}

# Delete namespace-scoped api resources for a particular namespace
function fix::rm-api-rs-in-ns {
  fix::ls-api-rs-in-ns $@ --delete
}

# Delete all instances for a particular resource
function fix::rm-rs-type {
  local namespace
  local includes=()
  local excludes=()
  local prompt
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; POSITIONAL+=("$1" "$2"); shift 2 ;;
    --include)
      includes+=("$2"); shift 2 ;;
    --exclude)
      excludes+=("$2"); shift 2 ;;
    -p|--prompt)
      prompt=1; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local resource_type=${POSITIONAL[0]}
  local resources

  if [[ -n $namespace ]]; then
    resources=($(oc get $resource_type -o name -n $namespace))
  elif [[ -n $all_namespaces ]]; then
    resources=($(oc get $resource_type -o name --all-namespaces))
  else
    resources=($(oc get $resource_type -o name))
  fi

  local num=${#resources[@]}
  local num_deleted=0

  logger::info "Found $num resource(s)."
   
  for resource in ${resources[@]}; do
    local is_excluded=0
    for exclude in ${excludes[@]}; do
      [[ $resource =~ $exclude ]] && is_excluded=1 && break
    done

    [[ $is_excluded == 1 ]] && logger::info "Resource $resource is excluded." && continue

    local is_included=0
    for include in ${includes[@]}; do
      [[ $resource =~ $include ]] && is_included=1 && break
    done

    [[ -n ${includes[@]} && $is_included == 0 ]] && continue

    local deletable=0
    [[ -n $prompt ]] && confirm "Do you want to delete $resource?" && deletable=1
    if [[ -z $prompt || $deletable == 1 ]]; then
      fix::rm-rs $resource ${POSITIONAL[@]:1}; (( num_deleted++ ))
    fi
  done

  logger::info "$num_deleted resource(s) deleted."
}

# Delete a particular resource instance
function fix::rm-rs {
  local namespace
  local force
  local clean_finalizer
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -f|--force)
      force=1; shift ;;
    --clean-finalizer)
      clean_finalizer=1; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local resource=${POSITIONAL[0]}
  [[ -n ${POSITIONAL[1]} ]] && resource="${resource}/${POSITIONAL[1]}"

  if [[ -n $namespace ]]; then
    logger::info "Deleting $resource in $namespace namespace ..."
    oc delete $resource -n $namespace --wait=false
    [[ $force == 1 ]] && oc delete $resource -n $namespace --wait=false --grace-period=0 --force
    [[ $clean_finalizer == 1 ]] && oc patch $resource -n $namespace -p '{"metadata":{"finalizers":[]}}' --type=merge
  else
    logger::info "Deleting $resource ..."
    oc delete $resource --wait=false
    [[ $force == 1 ]] && oc delete $resource --wait=false --grace-period=0 --force
    [[ $clean_finalizer == 1 ]] && oc patch $resource -p '{"metadata":{"finalizers":[]}}' --type=merge
  fi

}

fix "$@"
