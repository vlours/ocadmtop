# ocadmtop

This script will collect the PODs' resources consumption and display them by node.

### Usage
```
ocadmtop_node.sh [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-d {0-10}] [-v|-h]
  -c: sort by CPU (default)
  -m: sort by Memory
  -p: sort by namespace/pod
  -L: retrieve node(s) matching all labels
  -H: retrieve node(s) by hostname
  -A: retrieve All nodes (default)
  -d: debug/loglevel mode. Provide additional 'oc --loglevel' ouput. (Recommended value: 6)
  -v: Display the version
  -h: Display this help
ocadmtop_node.sh - Version: 0.3
```

### Examples
* Displaying ALL nodes (default) sorted by CPU (default)
```
$ ./ocadmtop_node.sh
```
* Displaying all master nodes sorted by MEM
```
$ ./ocadmtop_node.sh -L node-role.kubernetes.io/master -m
```
* Displaying some nodes sorted by POD
```
$ ./ocadmtop_node.sh -H master-1.lab.example.com,master-2.lab.example.com -p
```
* Displaying a node sorted by CPU with loglevel 6
```
$ ./ocadmtop_node.sh -H master-1.lab.example.com -d 6
```
