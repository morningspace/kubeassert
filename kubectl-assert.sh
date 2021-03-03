#!/bin/bash

# TODO:
# List all assertions and help info
# Custom assertion
# Itegrate w/ KUTTL

BLUE="\033[0;34m"
CYAN="\033[0;36m"
GREEN="\033[0;32m"
NORMAL="\033[0m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
WHITE="\033[0;37m"

WORKDIR=~/.kube-assert
mkdir -p $WORKDIR

function logger::info {
  printf "${CYAN}INFO  ${NORMAL}$@\n" >&2
}

function logger::warn {
  printf "${YELLOW}WARN  ${NORMAL}$@\n" >&2
}

function logger::error {
  printf "${RED}ERROR ${NORMAL}$1\n" >&2
}

function join {
  printf "$1"; shift
  printf "%s" "${@/#/,}"
}

function kg {
  [[ $VERBOSE == 1 ]] && echo -e "${CYAN}INFO  ${NORMAL}kubectl get $@" >&2
  kubectl get $@ > $WORKDIR/result.txt && ( [[ $VERBOSE == 1 ]] && cat $WORKDIR/result.txt || return 0 )
}

function assert_that {
  echo -e "${CYAN}INFO  ${NORMAL}Assert: $@" >&2
  IS_FAILED=0
}

function fail {
  echo -e "${CYAN}INFO  ${NORMAL}Assert: ${RED}FAIL${NORMAL} $@" >&2
  IS_FAILED=1
}

function list_assertion {
  echo "Supported assertions:"

  local assertions=($(cat $0 | grep "^function assert::.* {$" | awk '{print $2}'))
  for assertion in "${assertions[@]}"; do
    local description="$(cat $0 | grep "^function $assertion {$" -B1 | sed '2d')"
    printf "  %-36s %s\n" "${assertion#assert::}" "${description#\# }"
  done

  echo
}

function assert {
  local method="list_assertion"
  [[ -n $1 ]] && method="assert::$1"
  
  if type $method &>/dev/null ; then
    $method "${@:2}"
    [[ $IS_FAILED == 0 ]] && echo -e "${CYAN}INFO  ${NORMAL}Assert: ${GREEN}PASS${NORMAL}"
  else
    logger::error 'Unknown assertion "'$1'".\n'
    list_assertion
  fi
}

function parse_common_args {
  VERBOSE=''
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -v|--verbose)
      VERBOSE=1; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done
}

function parse_select_args {
  NAMESPACE=''
  ARG_NAMESPACE=''
  LABEL_SELECTOR=()
  ARG_LABEL_SELECTOR=()
  FIELD_SELECTOR=()
  ARG_FIELD_SELECTOR=()
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -n|--namespace)
      NAMESPACE="$2 namespace"
      ARG_NAMESPACE="$1 $2"; shift; shift ;;
    -A|--all-namespaces)
      NAMESPACE="all namespaces"
      ARG_NAMESPACE="$1";    shift ;;
    -l|--selector)
      LABEL_SELECTOR+=("$2")
      ARG_LABEL_SELECTOR+=("$1 $2");  shift; shift ;;
    --field-selector)
      FIELD_SELECTOR+=("$2")
      ARG_FIELD_SELECTOR+=("$1 $2");  shift; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done
}

function parse_op_val_args {
  OPERATOR=""
  EXPECTED_VAL=""
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    "-eq")
      OPERATOR="equal to"
      EXPECTED_VAL=$2; shift; shift ;;
    "-lt")
      OPERATOR="less than"
      EXPECTED_VAL=$2; shift; shift ;;
    "-gt")
      OPERATOR="greater than"
      EXPECTED_VAL=$2; shift; shift ;;
    "-ge")
      OPERATOR="no less than"
      EXPECTED_VAL=$2; shift; shift ;;
    "-le")
      OPERATOR="no greater than"
      EXPECTED_VAL=$2; shift; shift ;;
    *)
      POSITIONAL+=("$1"); shift ;;
    esac
  done

  # verify input
  [[ -z $OPERATOR || -z $EXPECTED_VAL ]] && logger::error "You must specify an operator with an expected value." && exit 1
}

function parse_resource_args {
  KIND=$1
  RESOURCE=$1
  [[ -n $2 ]] && RESOURCE="$1 $2"

  # verify input
  [[ -z $RESOURCE ]] && logger::error "You must specify the type of resource to get." && exit 1

  RESOURCE_FULLNAME="$RESOURCE"
  [[ $1 != *s ]] && [[ -z $2 ]] && RESOURCE_FULLNAME="$RESOURCE(s)"

  [[ -n ${LABEL_SELECTOR[@]} && -z ${FIELD_SELECTOR[@]} ]] && RESOURCE_FULLNAME+=" matching label criteria '`join ${LABEL_SELECTOR[@]}`'"
  [[ -z ${LABEL_SELECTOR[@]} && -n ${FIELD_SELECTOR[@]} ]] && RESOURCE_FULLNAME+=" matching field criteria '`join ${FIELD_SELECTOR[@]}`'"
  [[ -n ${LABEL_SELECTOR[@]} && -n ${FIELD_SELECTOR[@]} ]] && RESOURCE_FULLNAME+=" matching criteria for label '`join ${LABEL_SELECTOR[@]}`' and field '`join ${FIELD_SELECTOR[@]}`'"

  [[ -n $NAMESPACE ]] && RESOURCE_FULLNAME+=" in $NAMESPACE"
}

function parse_resource_row {
  if [[ $NAMESPACE == "all namespaces" ]]; then
    ROW_NAMESPACE=$1
    ROW_NAME=$2
    ROW_TOTAL_CONTAINERS=${3#*/}
    ROW_READY_CONTAINERS=${3%/*}
    ROW_STATUS=$4
    ROW_RESTARTS=$5
  else
    ROW_NAMESPACE=$NAMESPACE
    ROW_NAME=$1
    ROW_TOTAL_CONTAINERS=${2#*/}
    ROW_READY_CONTAINERS=${2%/*}
    ROW_STATUS=$3
    ROW_RESTARTS=$4
  fi
}

function parse_enhanced_selector {
  CUSTOM_COLUMNS=(
    NAME:.metadata.name
    NAMESPACE:.metadata.namespace
  )
  ENHANCED_OPERATORS=()
  ENHANCED_EXPECTED_VALS=()

  local selectors selector
  local field value
  local column_num=0

  for i in "${!FIELD_SELECTOR[@]}"; do
    IFS=',' read -r -a selectors <<< "${FIELD_SELECTOR[$i]}"
    for selector in ${selectors[@]}; do
      if [[ $selector =~ ^[^=~\!]+=[^=~\!]+ ]]; then
        field="${selector%=*}"
        value="${selector#*=}"
        ENHANCED_OPERATORS+=("equal to")
      elif [[ $selector =~ ^[^=~\!]+==[^=~\!]+ ]]; then
        field="${selector%==*}"
        value="${selector#*==}"
        ENHANCED_OPERATORS+=("equal to")
      elif [[ $selector =~ ^[^=~\!]+!=[^=~\!]+ ]]; then
        field="${selector%!=*}"
        value="${selector#*!=}"
        ENHANCED_OPERATORS+=("not equal to")
      elif [[ $selector =~ ^[^=~\!]+=~[^=~\!]+ ]]; then
        field="${selector%=~*}"
        value="${selector#*=~}"
        ENHANCED_OPERATORS+=("match")
      else
        logger::error "$selector is not a known field selector." && exit 1
      fi

      ! [[ $field =~ ^\..+ ]] && field=".$field"

      CUSTOM_COLUMNS+=("COL$column_num:$field")
      ENHANCED_EXPECTED_VALS+=("$value")

      (( column_num++ ))
    done
  done
}

#
# Usage: kubectl assert exist (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Example:
#
#   kubectl assert exist pods
#   kubectl assert exist replicaset -n default
#   kubectl assert exist deployment echo -n default
#   kubectl assert exist pods -l 'app=echo' -n default
#   kubectl assert exist pods --field-selector 'status.phase=Running' -n default
#   kubectl assert exist pods -l 'app=echo' --field-selector 'status.phase=Running' -n default
#   kubectl assert exist deployment,pod -l 'app=echo' --field-selector 'metadata.namespace==default' --all-namespaces
#
# Assert resource should exist.
function assert::exist {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should exist."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
    local list=(`cat $WORKDIR/result.txt`)
    local num=${#list[@]}
    if (( num == 0 )); then
      fail "Resource(s) not found."
    else
      logger::info "Found $num resource(s)."
      cat $WORKDIR/result.txt
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert not-exist (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Example:
#
#   kubectl assert not-exist pods
#   kubectl assert not-exist statefulsets -n default
#   kubectl assert not-exist deployment echo -n default
#   kubectl assert not-exist pods -l 'app=nginx' -n default
#   kubectl assert not-exist pods --field-selector 'status.phase=Running' -n default
#   kubectl assert not-exist pods -l 'app=nginx' --field-selector 'status.phase=Running' -n default
#   kubectl assert not-exist deployments,pods -l 'app=echo' --field-selector 'metadata.namespace==default' --all-namespaces
#
# Assert resource should not exist.
function assert::not-exist {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should not exist."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
    local list=(`cat $WORKDIR/result.txt`)
    local num=${#list[@]}
    if (( num > 0 )); then
      fail "Found $num resources(s)."
      cat $WORKDIR/result.txt
    else
      logger::info "Resource(s) not found."
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Example:
#
#   kubectl assert exist-enhanced pods --field-selector status.phase=Running --all-namespaces
#   kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 -n default
#   kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 --field-selector metadata.namespace=default --all-namespaces
#   kubectl assert exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=1
#   kubectl assert exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Running
#   kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp=='<none>' -A
#   kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' -A
#   kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running -A
#   kubectl assert exist-enhanced serviceaccounts --field-selector secrets[*].name=~inframgmtinstall-orchestrator-token.* -n manageiq
#   kubectl assert exist-enhanced serviceaccounts --field-selector secrets[*].name=~infra.* -n manageiq
#
# Assert resource should exist using enhanced field selector.
function assert::exist-enhanced {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@
  parse_enhanced_selector

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should exist."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} $ARG_NAMESPACE -o custom-columns=`join ${CUSTOM_COLUMNS[@]}`; then
    local line
    local line_num=0
    local lines=()

    while IFS= read -r line; do
      (( line_num++ ))
      (( line_num == 1 )) && lines+=("$line") && continue

      local parts=($line)
      local found=1
      for i in "${!ENHANCED_EXPECTED_VALS[@]}"; do
        (( j = i + 2 ))

        case "${ENHANCED_OPERATORS[$i]}" in
        "equal to")
          [[ ${parts[$j]} != ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        "not equal to")
          [[ ${parts[$j]} == ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        "match")
          [[ ! ${parts[$j]} =~ ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        esac
      done
      
      [[ $found == 1 ]] && lines+=("$line")
    done < $WORKDIR/result.txt

    if [ ${#lines[@]} -le 1 ]; then
      fail "Resource(s) not found."
    else
      logger::info "Found $(( ${#lines[@]} - 1 )) resource(s)."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert not-exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Example:
#
#   kubectl assert not-exist-enhanced pods --field-selector status.phase=Running --all-namespaces
#   kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=1 -n default
#   kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=1 --field-selector metadata.namespace=default --all-namespaces
#   kubectl assert not-exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=1
#   kubectl assert not-exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Running
#   kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp=='<none>' -A
#   kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' -A
#   kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running -A
#
# Assert resource should not exist using enhanced field selector.
function assert::not-exist-enhanced {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@
  parse_enhanced_selector

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should not exist."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} $ARG_NAMESPACE -o custom-columns=`join ${CUSTOM_COLUMNS[@]}`; then
    local line
    local line_num=0
    local lines=()

    while IFS= read -r line; do
      (( line_num++ ))
      (( line_num == 1 )) && lines+=("$line") && continue

      local parts=($line)
      local found=1
      for i in "${!ENHANCED_EXPECTED_VALS[@]}"; do
        (( j = i + 2 ))

        case "${ENHANCED_OPERATORS[$i]}" in
        "equal to")
          [[ ${parts[$j]} != ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        "not equal to")
          [[ ${parts[$j]} == ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        "match")
          [[ ! ${parts[$j]} =~ ${ENHANCED_EXPECTED_VALS[$i]} ]] && found=0 ;;
        esac
      done
      
      [[ $found == 1 ]] && lines+=("$line")
    done < $WORKDIR/result.txt

    if [ ${#lines[@]} -le 1 ]; then
      logger::info "Resource(s) not found."
    else
      fail "Found $(( ${#lines[@]} - 1 )) resource(s)."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert num (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options] (-eq|-lt|-gt|-ge|-le VALUE)
#
# Options:
#   -eq, -lt, -gt, -ge, -le: Check if the actual value is equal to, less than, greater than, no less than, or no greater than expected value.
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Examples:
#   kubectl assert num pods -n default -eq 10
#   kubectl assert num pods -l "app=echo" -n default -le 3
#   kubectl assert num pod echo -n default -gt 0
#   kubectl assert num pods --all-namespaces -ge 10
#   kubectl assert num pods -n default -le 10
#
# Assert the number of resource should match specified criteria.
function assert::num {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_op_val_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "the number of $RESOURCE_FULLNAME should be $OPERATOR $EXPECTED_VAL."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
    local list=(`cat $WORKDIR/result.txt`)
    local num=${#list[@]}
    case "$OPERATOR" in
    "equal to")
      (( num != EXPECTED_VAL )) && IS_FAILED=1 ;;
    "less than")
      (( num >= EXPECTED_VAL )) && IS_FAILED=1 ;;
    "greater than")
      (( num <= EXPECTED_VAL )) && IS_FAILED=1 ;;
    "no less than")
      (( num <  EXPECTED_VAL )) && IS_FAILED=1 ;;
    "no greater than")
      (( num >  EXPECTED_VAL )) && IS_FAILED=1 ;;
    esac    

    [[ $IS_FAILED != 0 ]] && fail "The actual number of $RESOURCE_FULLNAME is $num."
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert pod-not-terminating [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Examples:
#   kubectl assert pod-not-terminating -n default
#   kubectl assert pod-not-terminating --all-namespaces
#
# Assert pod should not keep terminating.
function assert::pod-not-terminating {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should not be terminating."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
    local line
    local line_num=0
    local lines=()

    while IFS= read -r line; do
      (( line_num++ ))
      (( line_num == 1 )) && lines+=("$line") && continue

      parse_resource_row $line

      [[ $ROW_STATUS == Terminating ]] && lines+=("$line")
    done < $WORKDIR/result.txt

    if [ ${#lines[@]} -gt 1 ]; then
      fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME terminating."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert pod-restarts [options] (-eq|-lt|-gt|-ge|-le VALUE)
#
# Options:
#   -eq, -lt, -gt, -ge, -le: Check if the actual value is equal to, less than, greater than, no less than, or no greater than expected value.
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Examples:
#   kubectl assert restarts pods -n default -lt 10
#   kubectl assert restarts pods -l 'app=echo' -n default -le 10
#
# Assert pod restarts should not match specified criteria.
function assert::pod-restarts {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_op_val_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "the restarts of $RESOURCE_FULLNAME should be $OPERATOR $EXPECTED_VAL."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
    local line
    local line_num=0
    local lines=()

    while IFS= read -r line; do
      (( line_num++ ))
      (( line_num == 1 )) && lines+=("$line") && continue

      parse_resource_row $line

      case "$OPERATOR" in
      "equal to")
        (( ROW_RESTARTS != EXPECTED_VAL )) && lines+=("$line") ;;
      "less than")
        (( ROW_RESTARTS >= EXPECTED_VAL )) && lines+=("$line") ;;
      "greater than")
        (( ROW_RESTARTS <=  EXPECTED_VAL )) && lines+=("$line") ;;
      "no less than")
        (( ROW_RESTARTS < EXPECTED_VAL )) && lines+=("$line") ;;
      "no greater than")
        (( ROW_RESTARTS >  EXPECTED_VAL )) && lines+=("$line") ;;
      esac    
    done < $WORKDIR/result.txt

    if [ ${#lines[@]} -gt 1 ]; then
      fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME restarts not $OPERATOR $EXPECTED_VAL."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert pod-ready [options]
#
# Options:
#   -A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace.
#       --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type.
#   -l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='.
#   -n, --namespace='': If present, the namespace scope for this CLI request.
#   -v: enable the verbose log.
#
# Assert pod should be ready.
function assert::pod-ready {
  parse_common_args $@

  set -- ${POSITIONAL[@]}
  parse_select_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  assert_that "$RESOURCE_FULLNAME should be ready."

  if kg $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
    local line
    local line_num=0
    local lines=()

    while IFS= read -r line; do
      (( line_num++ ))
      (( line_num == 1 )) && lines+=("$line") && continue

      parse_resource_row $line

      if (( $ROW_READY_CONTAINERS == $ROW_TOTAL_CONTAINERS )); then
        [[ $ROW_STATUS != Completed && $ROW_STATUS != Running ]] && lines+=("$line")
      else
        [[ $ROW_STATUS != Completed ]] && lines+=("$line")
      fi
    done < $WORKDIR/result.txt

    if [ ${#lines[@]} -gt 1 ]; then
      fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME not ready."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    fail "Error getting $RESOURCE_FULLNAME."
  fi
}

#
# Usage: kubectl assert apiservice-available [options]
#
# Options:
#   -v: enable the verbose log.
#
# Examples:
#   kubectl assert apiservice-available
#
# Assert apiservice should be available.
function assert::apiservice-available {
  parse_common_args $@

  assert_that "apiservices should be available."

  if kg apiservices; then
    if cat $WORKDIR/result.txt | grep -q False; then
      fail "Found apiservices not available."
      cat $WORKDIR/result.txt | grep False
    fi
  else
    fail "Error getting apiservices."
  fi
}

assert "$@"
