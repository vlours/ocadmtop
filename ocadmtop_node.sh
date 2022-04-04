#!/bin/bash
########################################################################
# Owner       # Red Hat - CEE
# Name        # ocadmtop_node.sh
# Description # Script to display detailed POD CPU/MEM usage on node
# Version     # 0.1
########################################################################

#### Functions
fct_usage() {
echo "$(basename $0) [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...]
  -c: sort by CPU (default)
  -m: sort by Memory
  -p: sort by namespace/pod
  -L: retrieve node(s) matching all labels
  -H: retrieve node(s) by hostname
  -A: retrieve All nodes (default)
  -h: Display this help"
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
{
while getopts ":cmpL:H:A" option;do
  case ${option} in
    c|m|p) SORT=${option} ;;
    H) NODES=$(echo ${OPTARG} |sed -e "s!,! !") ;;
    L) NODES=$(oc get nodes -l ${OPTARG} -o name | cut -d'/' -f2) ;;
    A) NODES=$(oc get nodes -o name | cut -d'/' -f2) ;;
    *) fct_usage
  esac
done

if [[ -z $NODES ]]
then
  NODES=$(oc get nodes -o name | cut -d'/' -f2)
fi

RESOURCES=$(oc adm top pod -A)
for NODE in ${NODES}
do
  echo -e "\n===== ${NODE} ====="
  PODS=$(oc describe node ${NODE} | awk '/Non-terminated Pods:/,/Allocated resources:/{if(($2 != "Pods:") && ($2 != "resources:") && ($2 != "----") && ($2 != "Name")){print $2}}')
  case ${SORT} in
    m) fct_mem | column -s'|' -t ;;
    p) fct_pod | column -s'|' -t ;;
    *) fct_cpu | column -s'|' -t ;;
  esac
done
}
