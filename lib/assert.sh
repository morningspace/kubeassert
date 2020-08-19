. $(dirname $0)/utils.sh

function filter_resource_resp {
  local resource_resp=$1
  local excludes=${@:2}
  local original_results=($(cat $resource_resp))
  local filtered_results=()
  for result in ${original_results[@]}; do
    local excluded=0
    for exclude in ${excludes[@]}; do
      [[ $result =~ $exclude ]] && excluded=1 && break;
    done
    [[ $excluded == 0 ]] && filtered_results+=($result)
  done
  echo ${filtered_results[@]}
}

function name_of {
  local resource=$1
  local group=${resource%/*}
  local name=${resource##*/}
  [[ $group == $name ]] && echo ${name%%.*} || echo ${group%%.*} $name
}

function should_not_keep_terminating_single {
  local resource=$1
  local resource_resp=$2
  local namespaces=$3
  local all_namespaces=$4
  local deteletion_timestamp=$(cat $resource_resp | jq -r .metadata.deletionTimestamp)
  if [[ -n $deteletion_timestamp && $deteletion_timestamp != null ]]; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      if [[ -n $namespace ]]; then
        logger::warn "deletionTimestamp detected on `name_of $resource` with value $deteletion_timestamp."
        logger::warn "Run 'kubectl get $resource -n $namespace -o yaml' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource -n $namespace -o yaml
      elif [[ -n $all_namespaces ]]; then
        logger::warn "deletionTimestamp detected on `name_of $resource` with value $deteletion_timestamp."
        logger::warn "Run 'kubectl get $resource --all-namespaces -o yaml' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource --all-namespaces -o yaml
      else
        logger::warn "deletionTimestamp detected on `name_of $resource` with value $deteletion_timestamp."
        logger::warn "Run 'kubectl get $resource -o yaml' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource -o yaml
      fi
    fi
  fi

  return $ASSERT_FAILED
}

function assert_step {
  echo -e "${CYAN}INFO ${BLUE} $@${NORMAL}"
}

function assert_start {
  ASSERT_FAILED=0
  echo -e -n "${CYAN}INFO ${NORMAL} Assert $@"
}

function assert_fail {
  if [[ $ASSERT_FAILED == 0 ]]; then
    echo -e "${RED}FAIL${NORMAL}"
    ASSERT_FAILED=1
  fi
}

function assert_end {
  if [[ $ASSERT_FAILED == 0 ]]; then
    echo -e "${GREEN}PASS${NORMAL}"
  fi
}

function assert_get_methods_info {
  ASSERT_METHODS_INFO=()
  local methods=($(cat $0 | grep "^function assert::.* {$" | awk '{print $2}'))
  for (( i = 0; i < ${#methods[@]}; i ++ )); do
    local method_name="${methods[$i]}"
    local method_description="$(cat $0 | grep $method_name -B1 | sed '2d')"
    ASSERT_METHODS_INFO+=("${method_name}|${method_description}")
  done
}

function assert_list {
  echo "Assertions:"

  assert_get_methods_info

  for method_info in "${ASSERT_METHODS_INFO[@]}"; do
    local method_name="${method_info%|*}"
    local method_description="${method_info#*|}"
    printf "  %-36s %s\n" "${method_name#assert::}" "${method_description#\# }"
  done
}

function assert_all {
  assert_get_methods_info

  for method_info in "${ASSERT_METHODS_INFO[@]}"; do
    local method_name="${method_info%|*}"
    local method_description="${method_info#*|}"
    assert_step "$method_description"
    $method_name "$@"
  done
}

function assert {
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -l|--list)
      POSITIONAL+=("list"); shift ;;
    -v|-v=*|--verbose=*)
      FLAG_VERBOSE=${1#*=}; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  method="assert_${POSITIONAL[0]:-all}"
  $method "${POSITIONAL[@]:1}"
}

# Specified resource should exist
function assert::should-exist {
  local namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
  local all_namespaces
  local includes
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -A|--all-namespaces)
      all_namespaces=1; shift ;;
    --includes)
      IFS=',' read -r -a includes <<< "$2"; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local resource=${POSITIONAL[0]}
  [[ -n ${POSITIONAL[1]} ]] && resource="${resource}/${POSITIONAL[1]}"

  if [[ -n $namespace ]]; then
    assert_start "`name_of $resource` should exist in $namespace namespace ... "
    resource_resp=$TEMP_PATH/$namespace.${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -n $namespace -o name 2>/dev/null > $resource_resp
    fi
  elif [[ -n $all_namespaces ]]; then
    assert_start "`name_of $resource` should exist in all namespaces ... "
    resource_resp=$TEMP_PATH/${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource --all-namespaces -o name 2>/dev/null > $resource_resp
    fi
  else
    assert_start "`name_of $resource` should exist in $namespace namespace ... "
    resource_resp=$TEMP_PATH/$namespace.${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -o name 2>/dev/null > $resource_resp
    fi
  fi

  if cat $resource_resp | grep -q $resource; then
    if [[ -n ${includes[@]} ]]; then
      for include in ${includes[@]}; do
        if ! cat $resource_resp | grep -q $include; then
          assert_fail

          if [[ -n $FLAG_VERBOSE ]]; then
            if [[ -n $namespace ]]; then
              logger::warn "`name_of $resource` $include not found in namespace $namespace."
              logger::warn "Run 'kubectl get $resource -n $namespace' to check details."
            elif [[ -n $all_namespaces ]]; then
              logger::warn "`name_of $resource` $include not found in all namespaces."
              logger::warn "Run 'kubectl get $resource --all-namespaces' to check details."
            else
              logger::warn "`name_of $resource` $include not found in namespace $namespace."
              logger::warn "Run 'kubectl get $resource' to check details."
            fi
          fi
        fi
      done
    fi
  else
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      if [[ -n $namespace ]]; then
        logger::warn "`name_of $resource` not found in namespace $namespace."
        logger::warn "Run 'kubectl get $resource -n $namespace' to check details."
      elif [[ -n $all_namespaces ]]; then
        logger::warn "`name_of $resource` not found in all namespaces."
        logger::warn "Run 'kubectl get $resource --all-namespaces' to check details."
      else
        logger::warn "`name_of $resource` not found in namespace $namespace."
        logger::warn "Run 'kubectl get $resource' to check details."
      fi
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Specified resource should not exist
function assert::should-not-exist {
  local namespace="$(kubectl config view --minify --output 'jsonpath={..namespace}')"
  local all_namespaces
  local excludes
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -A|--all-namespaces)
      all_namespaces=1; shift ;;
    --excludes)
      IFS=',' read -r -a excludes <<< "$2"; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local resource="${POSITIONAL[0]}"
  [[ -n ${POSITIONAL[1]} ]] && resource="${resource}/${POSITIONAL[1]}"

  if [[ -n $namespace ]]; then
    assert_start "`name_of $resource` should not exist in $namespace namespace ... "
    resource_resp=$TEMP_PATH/$namespace.${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -n $namespace -o name 2>/dev/null > $resource_resp
    fi
  elif [[ -n $all_namespaces ]]; then
    assert_start "`name_of $resource` should not exist in all namespaces ... "
    resource_resp=$TEMP_PATH/${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource --all-namespaces -o name 2>/dev/null > $resource_resp
    fi
  else
    assert_start "`name_of $resource` should not exist in $namespace namespace ... "
    resource_resp=$TEMP_PATH/$namespace.${resource/\//.}.name
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -o name 2>/dev/null > $resource_resp
    fi
  fi

  local results=($(filter_resource_resp $resource_resp ${excludes[@]}))
  if [[ -n ${results[@]} ]]; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      if [[ -n $namespace ]]; then
        logger::warn "`name_of $resource` found in namespace $namespace."
        logger::warn "Run 'kubectl get $resource -n $namespace' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource -n $namespace
      elif [[ -n $all_namespaces ]]; then
        logger::warn "`name_of $resource` found in all namespaces."
        logger::warn "Run 'kubectl get $resource --all-namespaces' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource --all-namespaces
      else
        logger::warn "`name_of $resource` found in namespace $namespace."
        logger::warn "Run 'kubectl get $resource' to check details."
        (( $FLAG_VERBOSE > 1 )) && kubectl get $resource
      fi
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Specified resource should not keep terminating
function assert::should-not-keep-terminating {
  local namespace
  local all_namespaces
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -A|--all-namespaces)
      all_namespaces=1; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local resource="${POSITIONAL[0]}"
  [[ -n ${POSITIONAL[1]} ]] && resource="${resource}/${POSITIONAL[1]}" || local is_list=1

  if [[ -n $namespace ]]; then
    assert_start "`name_of $resource` should not keep terminating in $namespace namespace ... "
    resource_resp=$TEMP_PATH/$namespace.${resource/\//.}
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -n $namespace -o json 2>/dev/null > $resource_resp
    fi
  elif [[ -n $all_namespaces ]]; then
    assert_start "`name_of $resource` should not keep terminating in all namespaces ... "
    resource_resp=$TEMP_PATH/${resource/\//.}
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource --all-namespaces -o json 2>/dev/null > $resource_resp
    fi
  else
    assert_start "`name_of $resource` should not keep terminating ... "
    resource_resp=$TEMP_PATH/${resource/\//.}
    if [[ ! -f $resource_resp ]]; then
      kubectl get $resource -o json 2>/dev/null > $resource_resp
    fi
  fi

  if [[ -n $is_list ]]; then
    local names=($(cat $resource_resp | jq -r '.items[].metadata.name'))
    for name in ${resources[@]}; do
      cat $resource_resp | jq -r ".items[] | select(.metadata.name==\"$name\")" > $resource_resp.$name
      should_not_keep_terminating_single $resource/$name $resource_resp.$name $namespace $all_namespaces
    done
  else
    should_not_keep_terminating_single $resource $resource_resp
  fi

  assert_end

  return $ASSERT_FAILED
}

# Helmrelease should be installed in specified namespace
function assert::helmrelease-should-be-installed {
  local namespace
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  assert_start "helmrelease should be installed in $namespace namespace ... "

  if kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml 2>/dev/null | grep -q InstallError; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      logger::warn "Some helmreleases are failed to install in $namespace namespace."
      logger::warn "Run 'kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml | grep InstallError -B 8' to check details."
      (( $FLAG_VERBOSE > 1 )) && kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml | grep InstallError -B 8
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Helmrelease should be deletable in specified namespace
function assert::helmrelease-should-be-deletable {
  local namespace
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  assert_start "helmrelease should be deletable in namespace $namespace ... "

  if kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml 2>/dev/null | grep -q Irreconcilable; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      logger::warn "Some helmreleases are failed to be deleted in namespace $namespace."
      logger::warn "Run 'kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml | grep Irreconcilable -B 8' to check details."
      (( $FLAG_VERBOSE > 1 )) && kubectl get helmreleases.apps.open-cluster-management.io -n $namespace -o yaml | grep Irreconcilable -B 8
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# The number of running pods in specified namespace should match specified criteria
function assert::pod-num {
  local status="running"
  local namespace
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local op=${POSITIONAL[0]}
  local expected_num=${POSITIONAL[1]}

  assert_start "the number of $status pods in $namespace namespace should be ${op//_/ } $expected_num ... "

  local actual_num=$(kubectl -n $namespace get pod 2>/dev/null | grep -i $status | wc -l)
  case "$op" in
  equal_to)
    (( actual_num != expected_num )) && assert_fail ;;
  less_than)
    (( actual_num >= expected_num )) && assert_fail ;;
  more_than)
    (( actual_num <= expected_num )) && assert_fail ;;
  no_less_than)
    (( actual_num < expected_num ))  && assert_fail ;;
  no_more_than)
    (( actual_num > expected_num ))  && assert_fail ;;
  esac    

  if [[ $ASSERT_FAILED != 0 && -n $FLAG_VERBOSE ]]; then
    logger::warn "The actual number of $status pods in $namespace namespace is $actual_num."
    logger::warn "Run 'kubectl get pod -n $namespace' to check details."
    (( $FLAG_VERBOSE > 1 )) && kubectl get pod -n $namespace
  fi

  assert_end

  return $ASSERT_FAILED
}

# API services should be available
function assert::api-service-should-be-available {
  assert_start "api services should be available ... "

  if kubectl get apiservices | grep -q False; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      logger::warn "Some api services are not available."
      logger::warn "Run 'kubectl get apiservices | grep False' to check details."
      (( $FLAG_VERBOSE > 1 )) && kubectl get apiservices | grep False
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Pods for specified lables in specified namespace should be running
function assert::pod {
  local status="running"
  local namespace
  local labels
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    -l|--label)
      labels=$2; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  assert_start "pods are $status for labels $labels in $namespace namespace ... "

  local resource_resp=$TEMP_PATH/$namespace.pods
  if [[ ! -f $resource_resp ]]; then
    kubectl get pod -n $namespace -l="$labels" 2>/dev/null > $resource_resp
  fi

  local parts
  local ready
  local status
  local restarts
  local containers_total
  local containers_running
  local line_num=0
  local failed_pods_lines=()

  while IFS= read -r pod_line; do
    (( line_num++ )); (( line_num == 1 )) && failed_pods_lines+=("$pod_line") && continue

    parts=($pod_line)

    ready=${parts[1]}
    status=${parts[2]}
    restarts=${parts[3]}

    containers_total=${ready#*/}
    containers_running=${ready%/*}

    local is_pod_failed=0

    if (( $containers_running == $containers_total )); then
      [[ $status != Completed && $status != Running ]] && is_pod_failed=1
    else
      [[ $status != Completed ]] && is_pod_failed=1
    fi

    (( restarts > restarts_cap && restarts_cap != 0 )) && is_pod_failed=1

    if [[ $is_pod_failed == 1 ]]; then
     failed_pods_lines+=("$pod_line")
    fi
  done < "$resource_resp"

  if [ ${#failed_pods_lines[@]} -gt 1 ]; then
    assert_fail

    if (( $FLAG_VERBOSE > 1 )); then
      logger::warn "Some failed pods found in $namespace namespace."
      logger::warn "Run 'kubectl get pod -n $namespace -l=\"$labels\"' to check details."
      for failed_pod_line in "${failed_pods_lines[@]}"; do
        echo "$failed_pod_line"
      done
    fi
  elif [ ${#failed_pods_lines[@]} -eq 1 ]; then
    local pods_lines_num=$(cat $resource_resp | wc -l)
    if [ $pods_lines_num -eq 1 ]; then
      assert_fail

      if (( $FLAG_VERBOSE > 1 )); then
        logger::warn "Pods are not found in $namespace namespace."
      fi
    fi
  else
    assert_fail
    
    if (( $FLAG_VERBOSE > 1 )); then
      logger::warn "Something wrong when get pods."
      logger::warn "Run 'kubectl get pod -n $namespace -l=\"$labels\"' to check details."
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Specified service account in specified namespace should include specified image pull secret
function assert::sa-should-include-image-pull-secret {
  local namespace
  local POSITIONAL=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      namespace=$2; shift 2 ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  local sa=${POSITIONAL[0]}
  local secret=${POSITIONAL[1]}

  assert_start "service account $sa in $namespace namespace should include image pull secret $secret ... "

  if ! kubectl get sa $sa -n $namespace -o json | jq -r .imagePullSecrets[].name | grep -q $secret; then
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      logger::warn "Image pull secret $secret not found in service account $sa in $namespace namespace."
      logger::warn "Run 'kubectl get sa $sa -n $namespace -o yaml' to check details."
      (( $FLAG_VERBOSE > 1 )) && kubectl get sa $sa -n $namespace -o yaml
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

# Secretshare should be cloned to target namespace
function assert::secretshare-should-be-cloned {
  local group=$1

  assert_start "$group should be cloned to target namespace ... "

  local resource_resp=$TEMP_PATH/secretshare
  if [[ ! -f $resource_resp ]]; then
    kubectl get secretshare -n ibm-common-services common-services -o json 2>/dev/null > $resource_resp
  fi

  declare -A check_list
  local resources=($(cat $resource_resp | jq -r .spec.${group}shares[].${group}name))
  for resource in ${resources[@]}; do
    local namespace=($(cat $resource_resp | jq -r ".spec.${group}shares[] | select(.${group}name == \"$resource\").sharewith[].namespace"))
    check_list[$namespace]+=" $resource"
  done

  if [[ -n ${check_list[@]} ]]; then
    for namespace in "${!check_list[@]}"; do
      expected_resources=(${check_list[$namespace]})
      local actual_resources=($(kubectl get $group -n $namespace -o name))
      for resource in ${expected_resources[@]}; do
        if [[ ! ${actual_resources[@]} =~ $resource ]]; then
          assert_fail

          if [[ -n $FLAG_VERBOSE ]]; then
            logger::warn "$group $resource not found in $namespace namespace."
          fi
        fi
      done
    done
  else
    assert_fail

    if [[ -n $FLAG_VERBOSE ]]; then
      logger::warn "$group not defined in secretshare."
      logger::warn "Run 'kubectl get secretshare -n ibm-common-services common-services -o yaml' to check details."
      (( $FLAG_VERBOSE > 1 )) && kubectl get secretshare -n ibm-common-services common-services -o yaml
    fi
  fi

  assert_end

  return $ASSERT_FAILED
}

assert_list "$@"
