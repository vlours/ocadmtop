# ocadmtop

This script will collect the PODs' resources consumption and display them by node.

## Usage

```bash
ocadmtop_node.sh [-c|-m|-p] [-C] [-u <m|u|n>] [-n <namesapce>] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-o <nodes|list|json>|-l|-j] [-t <TIMEOUT>] [-d {0-10}] [-v|-h]
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
  -h: Display this help
ocadmtop_node.sh - Version:  X.Y.Z
```

## Examples

* Displaying ALL nodes (default) sorted by CPU (default) with a timeout set to 2 minutes.

```bash
./ocadmtop_node.sh -t 2m
```

* Displaying all master nodes sorted by MEM

```bash
./ocadmtop_node.sh -L node-role.kubernetes.io/master -m
```

* Displaying some nodes sorted by POD

```bash
./ocadmtop_node.sh -H master-1.lab.example.com,master-2.lab.example.com -p
```

* Displaying a node sorted by CPU in nanocore unit with loglevel 6

```bash
./ocadmtop_node.sh -H master-1.lab.example.com -u n -d 6
```

* Displaying a specific namespace by MEM on all nodes in Json format

```bash
./ocadmtop_node.sh -n openshift-monitoring -m -o json
```

* Displaying the worker nodes PODS and containers sorted by CPU

```bash
./ocadmtop_node.sh -c -L node-role.kubernetes.io/worker= -C
```

* Displaying all worker nodes as list (not group by nodes) sorted by CPU in microcore

```bash
./ocadmtop_node.sh -L node-role.kubernetes.io/worker -l -u u
```

## What's new

* Version 1.2.0:
  * Support the new CPU units available since RHOCP 4.16 (m,u,n)
  * Improve the output readiness when displaying the containers statistics
  * Use colours to highlight the CPU/MEM usage and POD name in the output.
