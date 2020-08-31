#!/bin/bash

while :; do
    for N in $(dead-nodes); do
        echo "=== [$(date)] Node $N is dead. ==="
        sudo -u sgeadmin -i qmod -d all.q@$N
        for J in $(qstat -u \* | egrep ${N}\\. | awk '{print $1"."$10}' | sed 's/\.$//'); do
            qmod -rj $J
        done
        sudo -- bash -c "source /etc/profile.d/sge.sh; qconf -dattr hostgroup hostlist $N @allhosts; qconf -de $N"
    done
    for J in $(qstat|grep Eqw|awk '{print $1}'); do
        echo "=== [$(date)] Job $J has gotten error. ==="
        qalter -h u $J
    done
    sleep 60
done
