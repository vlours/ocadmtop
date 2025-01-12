# ocadmtop

This script will collect the PODs' resources consumption and display them by node.

## Usage

```bash
ocadmtop_node.sh [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-l] [-d {0-10}] [-t <TIMEOUT>][-v|-h]
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

* Displaying a node sorted by CPU with loglevel 6

```bash
./ocadmtop_node.sh -H master-1.lab.example.com -d 6
```

* Displaying a specific namespace by MEM on all nodes

```bash
./ocadmtop_node.sh -n openshift-monitoring -m
```

* Displaying the worker nodes PODS and containers sorted by CPU

```bash
./ocadmtop_node.sh -c -L node-role.kubernetes.io/worker= -C
```

* Displaying all worker nodes as list (not group by nodes)

```bash
./ocadmtop_node.sh -L node-role.kubernetes.io/worker -l
```
