#!/bin/bash

PYTHON_SCRIPT_PATH=$1

TMP="This variable might become useful at some point. Otherwise delete it." 

while true
do
    python2 "$PYTHON_SCRIPT_PATH"
    if ! python2 "$PYTHON_SCRIPT_PATH"; then
	      exitcode=$?
        echo "Script crashed with exit code $exitcode. Restarting..." >&2
        sleep 1
    fi
done
