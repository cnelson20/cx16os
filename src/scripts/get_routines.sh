#!/bin/bash

awk "{ print \$1 }" programs/cc65/routines.inc | grep -E "^[a-zA-Z0-9]" > /tmp/routines.txt
awk "{print \$NF }" $1 | grep -E "[a-z0-9]+" > /tmp/prog.txt
grep -Fwf /tmp/routines.txt /tmp/prog.txt | sort | uniq
