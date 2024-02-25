#!/bin/bash
########################################################################
# Owner       # Red Hat - CEE
# Name        # ocadmtop_node.sh
# Description # Script to display detailed POD CPU/MEM usage on node
# @VERSION    # 0.4
########################################################################

#### Functions
fct_usage() {
echo "$(basename $0) [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-d {0-10}] [-t <TIMEOUT>][-v|-h]
  -c: sort by CPU (default)
  -m: sort by Memory
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
  exit 1
}

fct_cpu() {
  echo "CPU|MEM|namespace/pod"
  for POD in ${PODS}; do echo "${RESOURCES}" | awk -v pod=${POD} '{if($2 == pod){print $3"|"$4"|"$1"/"$2}}'; done | sort -rn
}

fct_mem() {
  echo "MEM|CPU|namespace/pod"
  for POD in ${PODS}; do echo "${RESOURCES}" | awk -v pod=${POD} '{if($2 == pod){print $4"|"$3"|"$1"/"$2}}'; done | sort -rn
}

fct_pod() {
  echo "namespace/pod|CPU|MEM"
  for POD in ${PODS}; do echo "${RESOURCES}" | awk -v pod=${POD} '{if($2 == pod){print $1"/"$2"|"$3"|"$4}}'; done | sort
}

#### MAIN
VERSION=0.4
{
while getopts "cmpL:H:Ad:t:vh" option;do
  case ${option} in
    c|m|p) SORT=${option} ;;
    L) NODE_OPT=L && NODE_ARG=${OPTARG} ;;
    H) NODES=$(echo ${OPTARG} |sed -e "s!,! !") ;;
    A) NODE_OPT=A ;;
    d) if [[ ${OPTARG} =~ ^[1-9]$ ]] || [[ ${OPTARG} == 10 ]]; then LOGLEVEL="--loglevel ${OPTARG:-6}"; else fct_usage; fi ;;
    t) TIMEOUT=${OPTARG:-"1m"} ;;
    v) fct_version ;;
    h|*) fct_usage ;;
  esac
done
TIMEOUT=${TIMEOUT:-"1m"}
OC="oc --request-timeout=${TIMEOUT}"

if [[ -z $NODES ]]
then
  case ${NODE_OPT} in
    L)  NODES=$(${OC} get nodes -l ${NODE_ARG} -o name ${LOGLEVEL} | cut -d'/' -f2) ;;
    *)  NODES=$(${OC} get nodes -o name ${LOGLEVEL} | cut -d'/' -f2) ;;
  esac
fi

RESOURCES=$(${OC} adm top pod -A ${LOGLEVEL})
for NODE in ${NODES}
do
  echo -e "\n===== ${NODE} ====="
  PODS=$(${OC} describe node ${NODE} ${LOGLEVEL} | awk '/Non-terminated Pods:/,/Allocated resources:/{if(($2 != "Pods:") && ($2 != "resources:") && ($2 != "----") && ($2 != "Name")){print $2}}')
  case ${SORT} in
    m) fct_mem | column -s'|' -t ;;
    p) fct_pod | column -s'|' -t ;;
    *) fct_cpu | column -s'|' -t ;;
  esac
done
}
