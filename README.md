# ocadmtop

This script will collect the PODs' resources consumption and display them by node.

### Usage
```
ocadmtop_node.sh [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...]
  -c: sort by CPU (default)
  -m: sort by Memory
  -p: sort by namespace/pod
  -L: retrieve node(s) matching all labels
  -H: retrieve node(s) by hostname
  -A: retrieve All nodes (default)
  -h: Display this help
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
