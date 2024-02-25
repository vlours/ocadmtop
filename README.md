# ocadmtop

This script will collect the PODs' resources consumption and display them by node.

## Usage

```bash
ocadmtop_node.sh [-c|-m|-p] [-A|-L <label1>,<label2>,...|-H <host1>,<host2>,...] [-d {0-10}] [-t <TIMEOUT>][-v|-h]
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
  -h: Display this help
ocadmtop_node.sh - Version:  X.Y
```

## Examples

* Displaying ALL nodes (default) sorted by CPU (default)

```bash
./ocadmtop_node.sh
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
