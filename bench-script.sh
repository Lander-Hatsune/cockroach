#! /bin/bash

CRDB_BIN=./cockroach

# (re)import workload dataset
IMPORT_WORKLOAD=false

# switch cpu
SWITCH=false
# switch to record&replay mode after switching cpu
SWITCH_RECORD_AND_REPLAY=false

# tpcc parameters
## num of warehouses
WAREHOUSES=10
## ramp up time(s)
RAMP=0
## run time(ms)
RUN=2000
## seed
SEED=814

if [[ $IMPORT_WORKLOAD = true ]]; then
    echo "=== delete tpcc-local* workload ==="
    rm -r tpcc-local*

    echo "=== node start ==="
    $CRDB_BIN start \
    --insecure \
    --store=tpcc-local1 \
    --listen-addr=127.0.0.1:26257 \
    --http-addr=127.0.0.1:8080 \
    --join=127.0.0.1:26257 \
    --background

    echo "=== node init ==="
    $CRDB_BIN init \
    --insecure \
    --host=127.0.0.1:26257

    nc -zv 127.0.0.1 26257

    echo "=== workload import ==="
    $CRDB_BIN workload init tpcc \
    --warehouses=$WAREHOUSES \
    'postgresql://root@127.0.0.1:26257?sslmode=disable' \
    --data-loader=IMPORT \
    --seed=$SEED

    echo "=== kill multicore node ==="
    pkill -9 cockroach
fi


# direct settings
# export RECORD_AND_REPLAY=true
# export TRACE_TASKS=true

echo "=== node start ==="
SWITCH=$SWITCH \
SWITCH_RECORD_AND_REPLAY=$SWITCH_RECORD_AND_REPLAY \
taskset -c 0-1 \
$CRDB_BIN start \
--insecure \
--store=tpcc-local1 \
--listen-addr=127.0.0.1:26257 \
--http-addr=127.0.0.1:8080 \
--join=127.0.0.1:26257 \
--background

echo "=== node init ==="
$CRDB_BIN init \
--insecure \
--host=127.0.0.1:26257

nc -zv 127.0.0.1 26257

echo "=== workload run ==="
taskset -c 2 \
$CRDB_BIN workload run tpcc \
--warehouses=$WAREHOUSES \
--ramp="$RAMP"s \
--duration="$RUN"ms \
'postgresql://root@127.0.0.1:26257?sslmode=disable' \
--seed=$SEED

nc -zv 127.0.0.1 26257

echo "=== cockroach.log ==="
cat tpcc-local1/logs/cockroach.log
echo "=== cockroach-stderr.log ==="
cat tpcc-local1/logs/cockroach-stderr.log

echo "=== kill node ==="
pkill -9 cockroach
wait


