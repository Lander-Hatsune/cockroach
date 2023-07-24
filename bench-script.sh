#! /bin/bash

CRDB_BIN=./cockroach

# (re)import workload dataset
IMPORT_WORKLOAD=false

# switch cpu
SWITCH=false
# switch to record&replay mode after switching cpu
SWITCH_RECORD_AND_REPLAY=true

# tpcc parameters
## num of warehouses
WAREHOUSES=10
## ramp up time(s)
RAMP=0
## run time(ms)
RUN=2000
## seed
SEED=814

# direct settings
# export RECORD_AND_REPLAY=true
# export TRACE_TASKS=true

if [[ $IMPORT_WORKLOAD = true ]]; then
    echo "=== delete tpcc-local* workload ==="
    rm -r tpcc-local*
fi

echo "=== node start ==="
taskset -c 0-1 \
$CRDB_BIN start \
--insecure \
--store=tpcc-local1 \
--listen-addr=localhost:26257 \
--http-addr=localhost:8080 \
--join=localhost:26257,localhost:26258,localhost:26259 \
--background

echo "=== node init ==="
$CRDB_BIN init \
--insecure \
--host=localhost:26257

nc -zv localhost 26257

if [[ $IMPORT_WORKLOAD = true ]]; then
    echo "=== workload import ==="
    $CRDB_BIN workload fixtures import tpcc \
    --warehouses=$WAREHOUSES \
    'postgresql://root@localhost:26257?sslmode=disable' \
    --seed=$SEED
fi

echo "=== workload run ==="
taskset -c 2-3 \
$CRDB_BIN workload run tpcc \
--warehouses=$WAREHOUSES \
--ramp="$RAMP"s \
--duration="$RUN"ms \
'postgresql://root@localhost:26257?sslmode=disable' \
--seed=$SEED

echo "=== kill node ==="
pkill *cockroach* -9
wait


