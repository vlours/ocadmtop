#!/bin/bash
########################################################################
# Owner       # Red Hat - CEE
# Name        # ocadmtop_node.sh
# Description # Script to display detailed POD CPU/MEM usage on node
# @VERSION    # 0.6.1
########################################################################

#### Functions
fct_usage() {
echo "$(basename $0) [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-d {0-10}] [-t <TIMEOUT>][-v|-h]
  -c: sort by CPU (default)
  -m: sort by Memory
  -n: filter on a specific namespace PODs
  -p: sort by namespace/pod
  -L: retrieve node(s) matching all labels
  -H: retrieve node(s) by hostname
  -A: retrieve All nodes (default)
  -d: debug/loglevel mode. Provide additional 'oc --loglevel' ouput. (Recommended value: 6)
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
  echo -e "CPU|MEM|namespace/pod\n---|---|-------------|"
  for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    echo "${RESOURCES}" | awk -v pod_name=${POD} -v namespace_name=${NAMESPACE} '{if(($1 == namespace_name) && ($2 == pod_name)){printf "%dm|%dMi|%s\n",$3,$4,$1"/"$2}}'
  done | sort -rn
}

fct_mem() {
  echo -e "MEM|CPU|namespace/pod\n---|---|-------------|"
  for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    echo "${RESOURCES}" | awk -v pod_name=${POD} -v namespace_name=${NAMESPACE} '{if(($1 == namespace_name) && ($2 == pod_name)){printf "%dMi|%dm|%s\n",$4,$3,$1"/"$2}}'
  done | sort -rn
}

fct_pod() {
  echo -e "namespace/pod|CPU|MEM\n-------------|---|---|"
  for POD_DETAILS in ${POD_LIST}
  do
    NAMESPACE=$(echo ${POD_DETAILS} | cut -d'/' -f1)
    POD=$(echo ${POD_DETAILS} | cut -d'/' -f2)
    echo "${RESOURCES}" | awk -v pod_name=${POD} -v namespace_name=${NAMESPACE} '{if(($1 == namespace_name) && ($2 == pod_name)){printf "%s|%dm|%dMi\n",$1"/"$2,$3,$4}}'
  done | sort
}

#### MAIN
{
OPTNUM=0
while getopts "cmpn:L:H:Ad:t:vh" option;do
  case ${option} in
    c|m|p) SORT=${option} ;;
    n) NAMESPACE="${OPTARG}" ;;
    L) NODE_OPT=L && NODE_ARG=${OPTARG} && OPTNUM=$[OPTNUM + 1] ;;
    H) NODES=$(echo ${OPTARG} |sed -e "s!,! !") && OPTNUM=$[OPTNUM + 1] ;;
    A) NODE_OPT=A && OPTNUM=$[OPTNUM + 1] ;;
    d) if [[ ${OPTARG} =~ ^[1-9]$ ]] || [[ ${OPTARG} == 10 ]]; then LOGLEVEL="--loglevel ${OPTARG:-6}"; else fct_usage; fi ;;
    t) TIMEOUT=${OPTARG:-"1m"} ;;
    v) fct_version ;;
    h|*) fct_usage ;;
  esac
done
TIMEOUT=${TIMEOUT:-"1m"}
OC="oc --request-timeout=${TIMEOUT}"

if [[ ${OPTNUM} -gt 1 ]]
then
  echo "ERR: Too many node filters used (${OPTNUM}). Please limit to a single [-H|-L|-A] option"
  RC=5 && fct_usage
fi

if [[ -z $NODES ]]
then
  case ${NODE_OPT} in
    L)  NODES=$(${OC} get nodes -l ${NODE_ARG} -o name ${LOGLEVEL} | cut -d'/' -f2) ;;
    *)  NODES=$(${OC} get nodes -o name ${LOGLEVEL} | cut -d'/' -f2) ;;
  esac
fi
if [[  -z $NODES ]]
then
  echo "WARN: Unable to retrieve the list on Nodes. Please review your [-H|-L|-A] option"
  RC=10 && fct_usage
fi

# build the main Variables based on NAMESPACE or NOT (RESOURCES: metrics && ALL_FILTERED_PODS: List of PODs)
if [[ ! -z ${NAMESPACE} ]]
then
  RESOURCES=$(${OC} ${LOGLEVEL} get --raw "/apis/metrics.k8s.io/v1beta1/namespaces/${NAMESPACE}/pods" ${LOGLEVEL} | jq -r '.items[] | "\(.metadata | "\(.namespace) \(.name)") \([.containers[].usage.cpu | gsub("m";"") | tonumber] | add) \([.containers[].usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end] | add | . / 1024)"')
  ALL_FILTERED_PODS=$(${OC} ${LOGLEVEL} get pod -A -o wide | awk -v namespace_name=${NAMESPACE} '{if(($4 != "Completed")&&($1 == namespace_name)){print $1"/"$2" "$(NF-2)}}')
else
  RESOURCES=$(${OC} ${LOGLEVEL} get --raw "/apis/metrics.k8s.io/v1beta1/pods" ${LOGLEVEL} | jq -r '.items[] | "\(.metadata | "\(.namespace) \(.name)") \([.containers[].usage.cpu | gsub("m";"") | tonumber] | add) \([.containers[].usage.memory | if(contains("Mi")) then (gsub("Mi";"") | tonumber | . * 1024) elif (contains("Gi")) then (gsub("Gi";"") | tonumber | . * 1024 * 1024) else (gsub("Ki";"") | tonumber) end] | add | . / 1024)"')
  ALL_FILTERED_PODS=$(${OC} ${LOGLEVEL} get pod -A -o wide | awk '{if($4 != "Completed"){print $1"/"$2" "$(NF-2)}}')
fi
for NODE in ${NODES}
do
  echo -e "\n===== ${NODE} ====="
  POD_LIST=$(echo "${ALL_FILTERED_PODS}" | awk -v nodename=${NODE} '{if($2 == nodename){print $1}}')
  case ${SORT} in
    m) fct_mem | column -s'|' -t ;;
    p) fct_pod | column -s'|' -t ;;
    *) fct_cpu | column -s'|' -t ;;
  esac
done
echo
}
