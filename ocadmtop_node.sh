#!/bin/bash
########################################################################
# Owner       # Red Hat - CEE
# Name        # ocadmtop_node.sh
# Description # Script to display detailed POD CPU/MEM usage on node
# @VERSION    # 1.2.0
########################################################################

#### Functions
fct_usage() {
echo "$(basename $0) [-c|-m|-p] [-C] [-u <m|u|n>] [-n <namesapce>] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-o <nodes|list|json>|-l|-j] [-t <TIMEOUT>] [-d {0-10}] [-v|-h]
  -c: Sort by CPU (default)
  -m: Sort by Memory
  -p: Sort by namespace/pod
  -C: Display the container details. (Default: false)
  -u: Set the PODs' CPU unit to millicore (m), microcore (u) or nanocore (n). (Default: m)
  -n: Filter on a specific namespace PODs
  -A: Retrieve All nodes (default)
  -L: Retrieve node(s) matching all labels
  -H: Retrieve node(s) by hostname
  -o: Set the format
      - nodes: Grouped by nodes                             (default)
      - list:  Not grouped by nodes                         (short option: '-l')
      - json:  raw json format using nanocores as CPU unit  (short option: '-j')
  -t: The length of time to wait before giving up on a single server request. Non-zero values should contain a
      corresponding time unit (e.g. 1s, 2m, 3h). A value of zero means don't timeout requests.
  -d: Debug/loglevel mode. Provide additional 'oc --loglevel' ouput. (Recommended value: 6)
  -v: Display the version
  -h: Display this help"
fct_version
}

fct_version() {
  Script=$(which $0 2>${STD_ERR})
  VERSION=$(grep "@VERSION" ${Script} 2>${STD_ERR} | grep -Ev "VERSION=" | cut -d'#' -f3)
  VERSION=${VERSION:-" N/A"}
  echo "$(basename $0) - Version: ${VERSION}"
  exit ${RC:-0}
}

fct_cpu() {
  SORTED_LIST=$(for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
    if [[ ${OUTPUT} == "list" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.mem_usage*100 | round/100)!\(.namespace)/\(.name)!\($nodename)"'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.mem_usage*100 | round/100)!\(.namespace)/\(.name)"'
    fi
  done | sort -rn)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "CPU (${UNIT})!MEM (Mi)!namespace/pod!nodename\n-------!--------!-------------!--------"
    else
      echo -e "CPU (${UNIT})!MEM (Mi)!namespace/pod\n-------!--------!-------------"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "CPU (${UNIT})!MEM (Mi)!namespace/pod (|-> container)!nodename\n-------!--------!-----------------------------!--------"
    else
      echo -e "CPU (${UNIT})!MEM (Mi)!namespace/pod (|-> container)\n-------!--------!-----------------------------"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by(-(.usage.cpu | if(contains("m")) then (gsub("m";"") | tonumber | . * 1000000) elif (contains("u")) then (gsub("u";"") | tonumber | . * 1000) else (gsub("n";"") | tonumber) end))|.[]|" ! ! |->\(.name)!CPU: \(.usage.cpu)!MEM: \(.usage.memory)")"'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' -v unit=${UNIT} 'BEGIN{cpu=0;mem=0}{cpu+=$1;mem+=$2}END{if (unit == "n"){printf "%-12d!%-12.2f!=== TOTAL ===\n",cpu,mem}else{printf "%-12.2f!%-12.2f!=== TOTAL ===\n",cpu,mem}}'
 }

fct_mem() {
  SORTED_LIST=$(for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
    if [[ ${OUTPUT} == "list" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.mem_usage*100 | round/100)!\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.namespace)/\(.name)!\($nodename)"'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.mem_usage*100 | round/100)!\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.namespace)/\(.name)"'
    fi
  done | sort -rn)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "MEM (Mi)!CPU (${UNIT})!namespace/pod!nodename\n--------!-------!-------------!--------"
    else
      echo -e "MEM (Mi)!CPU (${UNIT})!namespace/pod\n--------!-------!-------------"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "MEM (Mi)!CPU (${UNIT})!namespace/pod (|-> container)!nodename\n--------!-------!-----------------------------!--------"
    else
      echo -e "MEM (Mi)!CPU (${UNIT})!namespace/pod (|-> container)\n--------!-------!-----------------------------"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by(-(.usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end))|.[]|" ! ! |->\(.name)!MEM: \(.usage.memory)!CPU: \(.usage.cpu) ")"'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' -v unit=${UNIT} 'BEGIN{cpu=0;mem=0}{cpu+=$2;mem+=$1}END{if (unit == "n"){printf "%-12.2f!%-12d!=== TOTAL ===\n",mem,cpu}else{printf "%-12.2f!%-12.2f!=== TOTAL ===\n",mem,cpu}}'
}

fct_pod() {
  SORTED_LIST=$(for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
    if [[ ${OUTPUT} == "list" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.namespace)/\(.name)!\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.mem_usage*100 | round/100)!\($nodename)"'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg unit ${UNIT} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.namespace)/\(.name)!\(if ($unit == "m") then .cpu_usage / 1000000 elif ($unit == "u") then .cpu_usage / 1000 else .cpu_usage end | .*100 | round/100)!\(.mem_usage*100 | round/100)"'
    fi
  done | sort)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "namespace/pod!CPU (${UNIT})!MEM (Mi)!nodename\n-------------!-------!--------!--------"
    else
      echo -e "namespace/pod!CPU (${UNIT}m)!MEM (Mi)\n-------------!-------!--------"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${OUTPUT} == "list" ]]
    then
      echo -e "namespace/pod (|-> container)!CPU (${UNIT})!MEM (Mi)!nodename\n-----------------------------!-------!--------!--------"
    else
      echo -e "namespace/pod (|-> container)!CPU (${UNIT})!MEM (Mi)\n-----------------------------!-------!--------"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $1}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $1}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by((.name))|.[]|" |->\(.name)!\(.usage.cpu)!\(.usage.memory)")"'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' -v unit=${UNIT} 'BEGIN{cpu=0;mem=0}{cpu+=$2;mem+=$3}END{if (unit == "n"){printf "=== TOTAL ===!%-12d!%-12.2f\n",cpu,mem}else{printf "=== TOTAL ===!%-12.2f!%-12.2f\n",cpu,mem}}'
}

#### MAIN
{
#Define Colors
graytext="\x1B[30m"
redtext="\x1B[31m"
greentext="\x1B[32m"
yellowtext="\x1B[33m"
bluetext="\x1B[34m"
purpletext="\x1B[35m"
cyantext="\x1B[36m"
whitetext="\x1B[37m"
resetcolor="\x1B[0m"

OPTNUM=0
while getopts "cmpCu:n:AL:H:o:ljt:d:vh" option;do
  case ${option} in
    c|m) COL1=12; COL2=12; COL3=${MAX_PODNAME_LENGTH}; SORT=${option} ;;
    p) COL1=${MAX_PODNAME_LENGTH}; COL2=12; COL3=12; SORT=${option} ;;
    C) CONTAINERS=true ;;
    u) UNIT="${OPTARG}" ;;
    n) NAMESPACE="${OPTARG}" ;;
    A) NODE_OPT=A && OPTNUM=$[OPTNUM + 1] ;;
    L) NODE_OPT=L && NODE_ARG=${OPTARG} && OPTNUM=$[OPTNUM + 1] ;;
    H) NODE_OPT=H && NODES=$(echo ${OPTARG} |sed -e "s!,! !") && OPTNUM=$[OPTNUM + 1] ;;
    o) OUTPUT="${OPTARG}" ;;
    l) OUTPUT="list" ;;
    j) OUTPUT="json" ;;
    t) TIMEOUT=${OPTARG:-"1m"} ;;
    d) if [[ ${OPTARG} =~ ^[1-9]$ ]] || [[ ${OPTARG} == 10 ]]; then LOGLEVEL="--loglevel ${OPTARG:-6}"; STD_ERR="/dev/stderr" ; else fct_usage; fi ;;
    v) fct_version ;;
    h|*) fct_usage ;;
  esac
done
TIMEOUT=${TIMEOUT:-"1m"}
OC="oc --request-timeout=${TIMEOUT}"
STD_ERR=${STD_ERR:-/dev/null}
OUTPUT=${OUTPUT:-"nodes"}
UNIT=${UNIT:-"m"}
COLUMN_SIZE=${COLUMN_SIZE:-12}

if [[ ${OPTNUM} -gt 1 ]]
then
  echo "ERR: Too many node filters used (${OPTNUM}). Please limit to a single [-H|-L|-A] option"
  RC=5 && fct_usage
fi

if [[ ${OUTPUT} != "nodes" ]] && [[ ${OUTPUT} != "list" ]] && [[ ${OUTPUT} != "json" ]]
then
  echo "ERR: Invalid output option '-o', please choose between 'nodes', 'list' or 'json' format."
  RC=7 && fct_usage
fi

if [[ -z ${NODES} ]]
then
  case ${NODE_OPT} in
    L)  NODES=$(${OC} get nodes -l ${NODE_ARG} -o name ${LOGLEVEL} 2>${STD_ERR} | cut -d'/' -f2) ;;
    *)  NODE_OPT=A && NODES=$(${OC} get nodes -o name ${LOGLEVEL} 2>${STD_ERR} | cut -d'/' -f2) ;;
  esac
fi
if [[  -z ${NODES} ]]
then
  echo "ERR: Unable to retrieve the list on Nodes. Please review your [-H|-L|-A] option"
  RC=10 && fct_usage
fi

# build the main Variables based on NAMESPACE or NOT (RESOURCES: metrics && ALL_FILTERED_PODS: List of PODs)
if [[ ! -z ${NAMESPACE} ]]
then
  ALL_RUNNING_POD_JSON=$(${OC} ${LOGLEVEL} get pod -n ${NAMESPACE} -o json 2>${STD_ERR} | jq -r '.items[] | select(.status.phase == "Running") | {name: .metadata.name,namespace: .metadata.namespace,nodeName: .spec.nodeName}')
  PODS_METRICS=$(${OC} ${LOGLEVEL} get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/${NAMESPACE}/pods" 2>${STD_ERR})
else
  ALL_RUNNING_POD_JSON=$(${OC} ${LOGLEVEL} get pod -A -o json 2>${STD_ERR} | jq -r '.items[] | select(.status.phase == "Running") | {name: .metadata.name,namespace: .metadata.namespace,nodeName: .spec.nodeName}')
  PODS_METRICS=$(${OC} ${LOGLEVEL} get --raw "/apis/metrics.k8s.io/v1beta1/pods"  2>${STD_ERR})
fi
if [[ ${NODE_OPT} == "A" ]]
then
  #Retrieving ALL Pods
  ALL_FILTERED_PODS=$(echo ${ALL_RUNNING_POD_JSON} | jq -rs '.[] | "\(.namespace)/\(.name)/\(.nodeName)"')
else
  # Filter to the desired nodes.
  ALL_FILTERED_PODS=""
  for NODE in ${NODES}
  do
      nodePODS=$(echo ${ALL_RUNNING_POD_JSON} | jq -rs --arg nodename ${NODE} '.[] | select(.nodeName == $nodename) | "\(.namespace)/\(.name)/\(.nodeName)"')
      if [[ -z ${ALL_FILTERED_PODS} ]]
      then
        ALL_FILTERED_PODS=${nodePODS}
      else
        ALL_FILTERED_PODS=$(echo -e "${ALL_FILTERED_PODS}\n${nodePODS}")
      fi
  done
fi

if [[ -z ${ALL_FILTERED_PODS} ]]
then
  echo -e "Warn: Unable to retrieve any POD matching the criterias. Please review the options used:\n\$ $(basename $0) $*\n"
  RC=15 && exit ${RC}
fi

# CPU are now using different units: milli (m), micro (u), or nona (n)
MAX_PODNAME_LENGTH=$(echo "${PODS_METRICS}" | jq -r '(.items | map((.metadata.namespace+.metadata.name) | length | . + 2)) | max') 
RESOURCES="$(echo "${PODS_METRICS}" | jq -r --arg unit ${UNIT} '.items[] |  {namespace: .metadata.namespace, name: .metadata.name, cpu_usage: ([.containers[].usage.cpu | if(contains("m")) then (gsub("m";"") | tonumber | . * 1000000) elif (contains("u")) then (gsub("u";"") | tonumber | . * 1000) else (gsub("n";"") | tonumber) end] | add), mem_usage: ([.containers[].usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end] | add | . / 1024), containers: [(.containers[] | select(.name != "POD"))] }' | jq -s)"

# Set the display columns
case ${SORT} in
  p) COL1=${MAX_PODNAME_LENGTH}; COL2=${COLUMN_SIZE}; COL3=${COLUMN_SIZE}; COL4=0; COL5=0;;
  *) COL1=${COLUMN_SIZE}; COL2=${COLUMN_SIZE}; COL3=${MAX_PODNAME_LENGTH}; COL4=$[COLUMN_SIZE+5]; COL5=$[COLUMN_SIZE+5];;
esac

#Extracting and displaying the data
case ${OUTPUT} in
  "json")
    POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk '{print $1"/"$2}')
    JSON_LIST=""
    for POD_DETAILS in ${POD_LIST}
    do
      NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
      POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
      NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
      NODENAME=${NODENAME:-"N/A"}
      POD_RESOURCES=$(echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} '.[] | select((.namespace == $namespace) and (.name == $pod)) | { "namespace": .namespace, "name": .name, "nodename": ($nodename),"cpu_usage": .cpu_usage, "cpu_unit": "n", "mem_usage": (.mem_usage | .*100 | round/100), "mem_unit": "Mi", "containers": .containers }')
      if [[ -z ${JSON_LIST} ]]
      then
        JSON_LIST="${POD_RESOURCES}"
      else
        JSON_LIST=$(echo "${JSON_LIST},${POD_RESOURCES}")
      fi
    done
    case ${SORT} in
      m) echo "[ ${JSON_LIST} ]" | jq -r 'sort_by(-.mem_usage)' ;;
      p) echo "[ ${JSON_LIST} ]" | jq -r 'sort_by(.namespace,.name)' ;;
      *) echo "[ ${JSON_LIST} ]" | jq -r 'sort_by(-.cpu_usage)' ;;
    esac
    ;;
  "list")
    if [[ $(echo ${NODES} | wc -l | awk '{print $1}') != 1 ]]
    then
      NODES=$(echo "${NODES}" | sed -e ':a' -e 'N;$!ba' -e 's/\n/|/g' -e 's/|$//')
    fi
    POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk '{print $1"/"$2}')
    case ${SORT} in
      m) fct_mem ;;
      p) fct_pod ;;
      *) fct_cpu ;;
    esac | awk -F'!' -v col1=${COL1} -v col2=${COL2} -v col3=${COL3} -v col4=${COL4} -v col5=${COL5} '{printf "%-*s %-*s %-*s %-*s %-*s\n",col1,$1,col2,$2,col3,$3,col4,$4,col5,$5}' | sed -e "s/[ \t]*$//" -e "s#^\([0-9.]\{1,\}\)\([ \t]\{1,\}\)\([0-9.]\{1,\}\)\([ \t]\{1,\}\)\([-a-z0-9]*/[-a-z0-9.]*\)#${yellowtext}\1${resetcolor}\2${yellowtext}\3${resetcolor}\4${purpletext}\5${resetcolor}#" -e "s#^\([-a-z0-9]*/[-a-z0-9.]*\)\([ \t]\{1,\}\)\([0-9.]\{1,\}\)\( *\)\([0-9.]\{1,\}\)#${purpletext}\1${resetcolor}\2${yellowtext}\3${resetcolor}\4${yellowtext}\5${resetcolor}#"
    ;;
  "nodes")
    for NODE in ${NODES}
    do
      echo -e "\n===== ${NODE} ====="
      POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk -F'/' -v nodename=${NODE} '{if($3 == nodename){print $1"/"$2}}')
      case ${SORT} in
        m) fct_mem;;
        p) fct_pod;;
        *) fct_cpu;;
      esac
    done | awk -F'!' -v col1=${COL1} -v col2=${COL2} -v col3=${COL3} -v col4=${COL4} -v col5=${COL5} '{printf "%-*s %-*s %-*s %-*s %-*s\n",col1,$1,col2,$2,col3,$3,col4,$4,col5,$5}' | sed -e "s/[ \t]*$//" -e "s#^\([0-9.]\{1,\}\)\([ \t]\{1,\}\)\([0-9.]\{1,\}\)\([ \t]\{1,\}\)\([-a-z0-9]*/[-a-z0-9.]*\)#${yellowtext}\1${resetcolor}\2${yellowtext}\3${resetcolor}\4${purpletext}\5${resetcolor}#" -e "s#^\([-a-z0-9]*/[-a-z0-9.]*\)\([ \t]\{1,\}\)\([0-9.]\{1,\}\)\( *\)\([0-9.]\{1,\}\)#${purpletext}\1${resetcolor}\2${yellowtext}\3${resetcolor}\4${yellowtext}\5${resetcolor}#"
    ;;
esac
echo
}
