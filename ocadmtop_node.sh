#!/bin/bash
########################################################################
# Owner       # Red Hat - CEE
# Name        # ocadmtop_node.sh
# Description # Script to display detailed POD CPU/MEM usage on node
# @VERSION    # 1.1.0
########################################################################

#### Functions
fct_usage() {
echo "$(basename $0) [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-l] [-d {0-10}] [-t <TIMEOUT>][-v|-h]
  -c: Sort by CPU (default)
  -l: Display the PODs in a full list (not grouped nodeName)
  -m: Sort by Memory
  -n: Filter on a specific namespace PODs
  -p: Sort by namespace/pod
  -L: Retrieve node(s) matching all labels
  -H: Retrieve node(s) by hostname
  -A: Retrieve All nodes (default)
  -C: Display the container details (default: false)
  -d: Debug/loglevel mode. Provide additional 'oc --loglevel' ouput. (Recommended value: 6)
  -t: The length of time to wait before giving up on a single server request. Non-zero values should contain a
      corresponding time unit (e.g. 1s, 2m, 3h). A value of zero means don't timeout requests.
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
    if [[ ${LIST} == "True" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} '.[] | select((.namespace == $namespace) and (.name == $pod)) | (.cpu_usage | tostring)+"!"+(.mem_usage*100 | round/100 | tostring)+"!"+(.namespace)+"/"+(.name)+"!"+$nodename'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.cpu_usage)!\(.mem_usage*100|round/100)!\(.namespace)/\(.name)"'
    fi
  done | sort -rn)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${LIST} == "True" ]]
    then
      echo -e "CPU (m)!MEM (Mi)!namespace/pod!nodename\n-------!--------!-------------!--------!"
    else
      echo -e "CPU (m)!MEM (Mi)!namespace/pod\n-------!--------!-------------!"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${LIST} == "True" ]]
    then
      echo -e "CPU (m)!MEM (Mi)!namespace/pod (|-> container)!nodename\n-------!--------!-----------------------------!--------!"
    else
      echo -e "CPU (m)!MEM (Mi)!namespace/pod (|-> container)\n-------!--------!-----------------------------!"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by(-(.usage.cpu | gsub("m";"") | tonumber))|.[]|" ! ! |->\(.name) / CPU: \(.usage.cpu) / MEM: \(.usage.memory)")"' |  column -ts'/'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' 'BEGIN{cpu=0;mem=0}{cpu+=$1;mem+=$2}END{printf "%sm!%sMi!=== TOTAL ===\n",cpu,mem}'
 }

fct_mem() {
  SORTED_LIST=$(for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
    if [[ ${LIST} == "True" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} '.[] | select((.namespace == $namespace) and (.name == $pod)) | (.mem_usage*100 | round/100 | tostring)+"!"+(.cpu_usage | tostring)+"!"+(.namespace)+"/"+(.name)+"!"+$nodename'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.mem_usage*100|round/100)!\(.cpu_usage)!\(.namespace)/\(.name)"'
    fi
  done | sort -rn)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${LIST} == "True" ]]
    then
      echo -e "MEM (Mi)!CPU (m)!namespace/pod!nodename\n--------!-------!-------------!--------!"
    else
      echo -e "MEM (Mi)!CPU (m)!namespace/pod\n--------!-------!-------------!"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${LIST} == "True" ]]
    then
      echo -e "MEM (Mi)!CPU (m)!namespace/pod (|-> container)!nodename\n--------!-------!-----------------------------!--------!"
    else
      echo -e "MEM (Mi)!CPU (m)!namespace/pod (|-> container)\n--------!-------!-----------------------------!"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $3}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by(-(.usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end))|.[]|" ! ! |->\(.name) / MEM: \(.usage.memory) / CPU: \(.usage.cpu) ")"' |  column -ts'/'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' 'BEGIN{cpu=0;mem=0}{cpu+=$2;mem+=$1}END{printf "%sMi!%sm!=== TOTAL ===\n",mem,cpu}'
}

fct_pod() {
  SORTED_LIST=$(for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    NODENAME=$(echo ${POD_DETAILS} | cut -d'/' -f3)
    if [[ ${LIST} == "True" ]]
    then
      NODENAME=${NODENAME:-"N/A"}
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} --arg nodename ${NODENAME} '.[] | select((.namespace == $namespace) and (.name == $pod)) | (.namespace)+"/"+(.name)+"!"+$nodename+"!"+(.cpu_usage | tostring)+"!"+(.mem_usage*100 | round/100 | tostring)'
    else
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.namespace)/\(.name)!\(.cpu_usage)!\(.mem_usage*100|round/100)"'
    fi
  done | sort)
  if [[ -z ${CONTAINERS} ]]
  then
    if [[ ${LIST} == "True" ]]
    then
      echo -e "namespace/pod!nodename!CPU (m)!MEM (Mi)\n-------------!--------!-------!--------!"
    else
      echo -e "namespace/pod!CPU (m)!MEM (Mi)\n!-------------!-------!--------!"
    fi
    echo "${SORTED_LIST}"
  else
    if [[ ${LIST} == "True" ]]
    then
      echo -e "namespace/pod (|-> container)!nodename!CPU (m)!MEM (Mi)\n-----------------------------!--------!-------!--------!"
    else
      echo -e "namespace/pod (|-> container)!CPU (m)!MEM (Mi)\n!-----------------------------!-------!--------!"
    fi
    for SORTED_POD in ${SORTED_LIST}
    do
      echo "${SORTED_POD}"
      NAMESPACE=$(echo ${SORTED_POD} | awk -F'!' '{print $1}' | cut -d'/' -f1)
      POD=$(echo ${SORTED_POD} | awk -F'!' '{print $1}' | cut -d'/' -f2)
      echo "${RESOURCES}" | jq -r --arg namespace ${NAMESPACE} --arg pod ${POD} '.[] | select((.namespace == $namespace) and (.name == $pod)) | "\(.containers|sort_by((.name))|.[]|" |->\(.name) / CPU: \(.usage.cpu) / MEM: \(.usage.memory)")"' |  column -ts'/'
    done
  fi
  echo "${SORTED_LIST}" | awk -F'!' 'BEGIN{cpu=0;mem=0}{cpu+=$3;mem+=$4}END{printf " !=== TOTAL ===!%sm!%sMi\n",cpu,mem}'
}

#### MAIN
{
OPTNUM=0
while getopts "clmpn:L:H:ACd:t:vh" option;do
  case ${option} in
    c|m|p) SORT=${option} ;;
    l) LIST="True";;
    n) NAMESPACE="${OPTARG}" ;;
    L) NODE_OPT=L && NODE_ARG=${OPTARG} && OPTNUM=$[OPTNUM + 1] ;;
    H) NODE_OPT=H && NODES=$(echo ${OPTARG} |sed -e "s!,! !") && OPTNUM=$[OPTNUM + 1] ;;
    A) NODE_OPT=A && OPTNUM=$[OPTNUM + 1] ;;
    C) CONTAINERS=true ;;
    d) if [[ ${OPTARG} =~ ^[1-9]$ ]] || [[ ${OPTARG} == 10 ]]; then LOGLEVEL="--loglevel ${OPTARG:-6}"; STD_ERR="/dev/stderr" ; else fct_usage; fi ;;
    t) TIMEOUT=${OPTARG:-"1m"} ;;
    v) fct_version ;;
    h|*) fct_usage ;;
  esac
done
TIMEOUT=${TIMEOUT:-"1m"}
OC="oc --request-timeout=${TIMEOUT}"
STD_ERR=${STD_ERR:-/dev/null}

if [[ ${OPTNUM} -gt 1 ]]
then
  echo "ERR: Too many node filters used (${OPTNUM}). Please limit to a single [-H|-L|-A] option"
  RC=5 && fct_usage
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
  echo "WARN: Unable to retrieve the list on Nodes. Please review your [-H|-L|-A] option"
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

RESOURCES="$(echo "${PODS_METRICS}" | jq -r '.items[] |  {namespace: .metadata.namespace, name: .metadata.name, cpu_usage: ([.containers[].usage.cpu | gsub("m";"") | tonumber] | add), mem_usage: ([.containers[].usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end] | add | . / 1024), containers: [(.containers[] | select(.name != "POD"))] }' | jq -s)"

# Collect the nodes metrics - Not in use as can bring confusion
# NODES_METRICS=$(${OC} ${LOGLEVEL} get --raw "/apis/metrics.k8s.io/v1beta1/nodes"  2>${STD_ERR})

#Extracting the data by node
if [[ ${LIST} == "True" ]]
then
  if [[ $(echo ${NODES} | wc -l | awk '{print $1}') != 1 ]]
  then
    NODES=$(echo "${NODES}" | sed -e ':a' -e 'N;$!ba' -e 's/\n/|/g' -e 's/|$//')
  fi
  POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk '{print $1"/"$2}')
  case ${SORT} in
    m) fct_mem | column -s'!' -t ;;
    p) fct_pod | column -s'!' -t ;;
    *) fct_cpu | column -s'!' -t ;;
  esac
else
  for NODE in ${NODES}
  do
    echo -e "\n===== ${NODE} ====="
    POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk -F'/' -v nodename=${NODE} '{if($3 == nodename){print $1"/"$2}}')
    case ${SORT} in
      m) fct_mem | column -s'!' -t ;;
      p) fct_pod | column -s'!' -t ;;
      *) fct_cpu | column -s'!' -t ;;
    esac
  done
fi
echo
}
