#!/bin/bash

PIPE_HOME=$(dirname $(readlink -f ${BASH_SOURCE[0]}))
PYTHON3=$PIPE_HOME/$(grep PYTHON3 $PIPE_HOME/config.ini |cut -f2 -d=|sed 's/^ \+//')

$PYTHON3 $PIPE_HOME/genome_mapping/run.py $@
