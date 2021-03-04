#!/bin/bash

# Custom assertion
# Itegrate w/ KUTTL

CYAN="\033[0;36m"
GREEN="\033[0;32m"
NORMAL="\033[0m"
RED="\033[0;31m"

WORKDIR=~/.kube-assert
mkdir -p $WORKDIR

function join {
  printf "$1"; shift
  printf "%s" "${@/#/,}"
}

function kubectl {
  [[ $VERBOSE == 1 ]] && logger::info "kubectl $@" >&2
  command kubectl $@ > $WORKDIR/result.txt && ( [[ $VERBOSE == 1 ]] && cat $WORKDIR/result.txt || return 0 )
}

function logger::info {
  echo -e "${CYAN}INFO   ${NORMAL}$@" >&2
}

function logger::error {
  echo -e "${RED}ERROR  ${NORMAL}$@" >&2
}

function logger::assert {
  echo -e "${CYAN}ASSERT ${NORMAL}$@" >&2
  IS_FAILED=0
}

function logger::fail {
  echo -e "${CYAN}ASSERT ${RED}FAIL${NORMAL} $@" >&2
  IS_FAILED=1
}

function logger::pass {
  [[ $IS_FAILED == 0 ]] && echo -e "${CYAN}ASSERT ${GREEN}PASS${NORMAL}"
}

function parse_common_args {
  VERBOSE=''
  HELP=''
  POSITIONAL=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
    -v|--verbose)
      VERBOSE=1; shift ;;
    -h|--help)
      HELP=1; shift ;;
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

function list_assertions {
  echo "Supported assertions:"
  local assertions=(`cat $0 | grep '^#.*@Name:' | awk '{print $3}'`)

  for assertion in "${assertions[@]}"; do
    local comment="`sed -n -e "/#.*@Name: $assertion$/,/function.*$assertion.*{/ p" $0 | sed -e '1d;$d'`"
    local description="`echo "$comment" | grep '^#.*@Description:' | sed -n 's/^#.*@Description:[[:space:]]*//p'`"
    printf "  %-36s %s\n" "$assertion" "$description"
  done
}

OP_VAL_OPTIONS=(
  "-eq, -lt, -gt, -ge, -le: Check if the actual value is equal to, less than, greater than, no less than, or no greater than expected value."
)
SELECT_OPTIONS=(
  "-A, --all-namespaces: If present, list the requested object(s) across all namespaces. Namespace in current context is ignored even if specified with --namespace."
  "    --field-selector='': Selector (field query) to filter on, supports '=', '==', and '!='. The server only supports a limited number of field queries per type."
  "-l, --selector='': Selector (label query) to filter on, supports '=', '==', and '!='."
  "-n, --namespace='': If present, the namespace scope for this CLI request."
)
GLOBAL_OPTIONS=(
  "-v, --verbose: Enable the verbose log."
  "-h, --help: Print the help information."
)

function show_assertion_help {
  local name="$1"
  local comment="`sed -n -e "/^#.*@Name: $name$/,/function.*$name.*{/ p" $0 | sed -e '1d;$d'`"
  local description="`echo "$comment" | grep '^#.*@Description:' | sed -n 's/^#.*@Description:[[:space:]]*//p'`"
  local usage="`echo "$comment" | grep '^#.*@Usage:' | sed -n 's/^#.*@Usage:[[:space:]]*//p'`"
  local options=()
  local examples=()
  local parsing

  while IFS= read -r line; do
    [[ $line =~ ^#.*@Options:$ ]] && parsing=Options && continue
    [[ $line =~ ^#.*@Examples:$ ]] && parsing=Examples && continue

    if [[ $parsing == Options ]] && [[ ! $line =~ ^#$ ]]; then
      if [[ $line =~ '${OP_VAL_OPTIONS}' ]]; then
        options+=("${OP_VAL_OPTIONS[@]}")
      elif [[ $line =~ '${SELECT_OPTIONS}' ]]; then
        options+=("${SELECT_OPTIONS[@]}")
      elif [[ $line =~ '${GLOBAL_OPTIONS}' ]]; then
        options+=("${GLOBAL_OPTIONS[@]}")
      else
        options+=("`echo $line | sed -n 's/^#[[:space:]]*//p'`")
      fi
    fi
    
    if [[ $parsing == Examples ]] && [[ ! $line =~ ^#$ ]]; then
      examples+=("`echo $line | sed -n 's/^#[[:space:]]*//p'`")
    fi
  done <<< "$comment"

  [[ -n $description ]] && echo "$description" || echo "$name"
  [[ -n $usage ]] && echo && echo "Usage: $usage"

  if [[ -n ${options[@]} ]]; then
    echo; echo "Options:"
    for option in "${options[@]}"; do echo "  $option"; done
  fi

  if [[ -n ${examples[@]} ]]; then
    echo; echo "Examples:"
    for example in "${examples[@]}"; do echo "  $example"; done
  fi
}

function run_assertion {
  parse_common_args $@

  local what=${POSITIONAL[0]}
  if [[ -n $what ]]; then
    if type $what &>/dev/null ; then
      if [[ $HELP == 1 ]]; then
        show_assertion_help $what
      else
        set -- ${POSITIONAL[@]}
        $what ${@:2}
        logger::pass
      fi
    else
      logger::error 'Unknown assertion "'$what'".' && exit 1
    fi
  else
    list_assertions
  fi
}

##
#
# @Name: exist
# @Description: Assert resource should exist.
# @Usage: kubectl assert exist (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert resources exist in current namespace
#   kubectl assert exist pods
#   # Assert resources exist in specified namespace 
#   kubectl assert exist replicasets -n default
#   # Assert specified resource exists 
#   kubectl assert exist deployment echo -n default
#   # Assert resources with specified label exist
#   kubectl assert exist pods -l 'app=echo' -n default
#   # Assert resources with specified field selector exist
#   kubectl assert exist pods --field-selector 'status.phase=Running' -n default
#   # Assert resources with specified label and field selector exist
#   kubectl assert exist pods -l 'app=echo' --field-selector 'status.phase=Running' -n default
#   # Assert resources with multiple specified lables and field selectors exist in some namespaces
#   kubectl assert exist deployment,pod -l 'app=echo,component=echo' --field-selector 'metadata.namespace==default' --all-namespaces
# 
function exist {
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should exist."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
    local list=(`cat $WORKDIR/result.txt`)
    local num=${#list[@]}
    if (( num == 0 )); then
      logger::fail "Resource(s) not found."
    else
      logger::info "Found $num resource(s)."
      cat $WORKDIR/result.txt
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: not-exist
# @Description: Assert resource should not exist.
# @Usage: kubectl assert not-exist (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert resources not exist in current namespace
#   kubectl assert not-exist pods
#   # Assert resources not exist in specified namespace
#   kubectl assert not-exist statefulsets -n default
#   # Assert specified resource not exist
#   kubectl assert not-exist deployment echo -n default
#   # Assert resources with specified label not exist
#   kubectl assert not-exist pods -l 'app=echo' -n default
#   # Assert resources with specified field selector not exist
#   kubectl assert not-exist pods --field-selector 'status.phase=Error' -n default
#   # Assert resources with specified label and field selector not exist
#   kubectl assert not-exist pods -l 'app=echo' --field-selector 'status.phase=Error' -n default
#   # Assert resources with multiple specified lables and field selectors not exist in any namespace
#   kubectl assert not-exist deployments,pods -l 'app=echo,component=echo' --field-selector 'metadata.namespace==default' --all-namespaces
# 
function not-exist {
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should not exist."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
    local list=(`cat $WORKDIR/result.txt`)
    local num=${#list[@]}
    if (( num > 0 )); then
      logger::fail "Found $num resources(s)."
      cat $WORKDIR/result.txt
    else
      logger::info "Resource(s) not found."
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: exist-enhanced
# @Description: Assert resource should exist using enhanced field selector.
# @Usage: kubectl assert exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert pods in running status exist in current namespace
#   kubectl assert exist-enhanced pods --field-selector status.phase=Running
#   # Assert pods with specified label in running status exist
#   kubectl assert exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Running
#   # Assert pods being deleted exist in some namespaces
#   kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' --all-namespaces
#   # Assert pods being deleted keeping running exist in some namespaces
#   kubectl assert exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running --all-namespaces
#   # Assert deployments have specified replicas ready
#   kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 -n default
#   kubectl assert exist-enhanced deployments --field-selector status.readyReplicas=1 --field-selector metadata.namespace=default --all-namespaces
#   # Assert deployments with specified label have specified replicas ready
#   kubectl assert exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=1
#   # Assert service accounts with specified secret exist using regex
#   kubectl assert exist-enhanced serviceaccounts --field-selector secrets[*].name=~my-secret -n default
#   # Assert MyResources with specified status exist using regex
#   kubectl assert exist-enhanced MyResources --field-selector status.conditions[*].type=~Deployed -n default
#   # Assert MyResources with their names in a specified list exist using regex
#   kubectl assert exist-enhanced MyResource --field-selector metadata.name=~'foo.*|bar.*|baz.*' -n default
# 
function exist-enhanced {
  parse_select_args $@
  parse_enhanced_selector

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should exist."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} $ARG_NAMESPACE -o custom-columns=`join ${CUSTOM_COLUMNS[@]}`; then
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
      logger::fail "Resource(s) not found."
    else
      logger::info "Found $(( ${#lines[@]} - 1 )) resource(s)."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: not-exist-enhanced
# @Description: Assert resource should not exist using enhanced field selector.
# @Usage: kubectl assert not-exist-enhanced (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert pods in error status not exist in current namespace
#   kubectl assert not-exist-enhanced pods --field-selector status.phase=Error
#   # Assert pods with specified label in error status not exist
#   kubectl assert not-exist-enhanced pods --field-selector metadata.labels.app=echo,status.phase=Error
#   # Assert pods being deleted not exist in any namespace
#   kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>' --all-namespaces
#   # Assert pods being deleted keeping running not exist in some namespaces
#   kubectl assert not-exist-enhanced pods --field-selector metadata.deletionTimestamp!='<none>',status.phase==Running --all-namespaces
#   # Assert deployments have replicas not ready
#   kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=0 -n default
#   kubectl assert not-exist-enhanced deployments --field-selector status.readyReplicas=0 --field-selector metadata.namespace=default --all-namespaces
#   # Assert deployments with specified label have replicas not ready
#   kubectl assert not-exist-enhanced deployments --field-selector metadata.labels.app=echo,status.readyReplicas=0
#   # Assert namespace keeps terminating not exist
#   kubectl assert not-exist-enhanced namespace --field-selector metadata.deletetionTimestamp!='<none>',spec.finalizers[*]!='<none>'
# 
function not-exist-enhanced {
  parse_select_args $@
  parse_enhanced_selector

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should not exist."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} $ARG_NAMESPACE -o custom-columns=`join ${CUSTOM_COLUMNS[@]}`; then
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
      logger::fail "Found $(( ${#lines[@]} - 1 )) resource(s)."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: num
# @Description: Assert the number of resource should match specified criteria.
# @Usage: kubectl assert num (TYPE[.VERSION][.GROUP] [NAME | -l label] | TYPE[.VERSION][.GROUP]/NAME ...) [options] (-eq|-lt|-gt|-ge|-le VALUE)
# @Options:
#   ${OP_VAL_OPTIONS}
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert number of pods in specified namespace equal to specified value
#   kubectl assert num pods -n default -eq 10
#   # Assert number of pods in specified namespace less than specified value
#   kubectl assert num pods -n default -lt 11
#   # Assert number of pods with specified label in specified namespace no more than specified value
#   kubectl assert num pods -l "app=echo" -n default -le 3
#   # Assert number of specified pod greater than specified value
#   kubectl assert num pod echo -n default -gt 0
#
function num {
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_op_val_args $@

  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "The number of $RESOURCE_FULLNAME should be $OPERATOR $EXPECTED_VAL."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE -o name; then
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

    [[ $IS_FAILED != 0 ]] && logger::fail "The actual number of $RESOURCE_FULLNAME is $num."
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: pod-not-terminating
# @Description: Assert pod should not keep terminating.
# @Usage: kubectl assert pod-not-terminating [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert no pod terminating in specified namespace
#   kubectl assert pod-not-terminating -n default
#   # Assert no pod terminating in any namespace
#   kubectl assert pod-not-terminating --all-namespaces
# 
function pod-not-terminating {
  parse_select_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should not be terminating."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
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
      logger::fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME terminating."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: pod-restarts
# @Description: Assert pod restarts should not match specified criteria.
# @Usage: kubectl assert pod-restarts [options] (-eq|-lt|-gt|-ge|-le VALUE)
# @Options:
#   ${OP_VAL_OPTIONS}
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert restarts of pods less than specified value
#   kubectl assert restarts pods -n default -lt 10
#   # Assert restarts of pods with specified label in specified namespace no more than specified value
#   kubectl assert restarts pods -l 'app=echo' -n default -le 10
#   # Assert restarts of pods no more than specified value in any namespace
#   kubectl assert restarts pods --all-namespaces -lt 10
# 
function pod-restarts {
  parse_select_args $@

  set -- ${POSITIONAL[@]}
  parse_op_val_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "The restarts of $RESOURCE_FULLNAME should be $OPERATOR $EXPECTED_VAL."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
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
      logger::fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME restarts not $OPERATOR $EXPECTED_VAL."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: pod-ready
# @Description: Assert pod should be ready.
# @Usage: kubectl assert pod-ready [options]
# @Options:
#   ${SELECT_OPTIONS}
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert pods ready in specified namespace
#   kubectl assert pod-ready pods -n default
#   # Assert pods ready in all namespaces
#   kubectl assert pod-ready pods --all-namespaces
#
function pod-ready {
  parse_select_args $@

  POSITIONAL=(pod ${POSITIONAL[@]})
  set -- ${POSITIONAL[@]}
  parse_resource_args $@

  logger::assert "$RESOURCE_FULLNAME should be ready."

  if kubectl get $RESOURCE ${ARG_LABEL_SELECTOR[@]} ${ARG_FIELD_SELECTOR[@]} $ARG_NAMESPACE; then
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
      logger::fail "Found $(( ${#lines[@]} - 1 )) $RESOURCE_FULLNAME not ready."
      for line in "${lines[@]}"; do
        echo "$line"
      done
    fi
  else
    logger::fail "Error getting $RESOURCE_FULLNAME."
  fi
}

##
#
# @Name: apiservice-available
# @Description: Assert apiservice should be available.
# @Usage: kubectl assert apiservice-available [options]
# @Options:
#   ${GLOBAL_OPTIONS}
# @Examples:
#   # Assert apiservice available
#   kubectl assert apiservice-available
#
function apiservice-available {
  logger::assert "apiservices should be available."

  if kubectl get apiservices; then
    if cat $WORKDIR/result.txt | grep -q False; then
      logger::fail "Found apiservices not available."
      cat $WORKDIR/result.txt | grep False
    fi
  else
    logger::fail "Error getting apiservices."
  fi
}

run_assertion "$@"
