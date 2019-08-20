#!/bin/bash

PIPE_HOME=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
PYTHON3=$PIPE_HOME/$(grep PYTHON3 $PIPE_HOME/config.ini |cut -f2 -d=|sed 's/^ \+//')

cmd=$(basename $0)
$PYTHON3 $PIPE_HOME/variant_calling/run.py $@ \
    1> >(sed "s/run.py/$cmd/" >&1) \
    2> >(sed "s/run.py/$cmd/" >&2)
