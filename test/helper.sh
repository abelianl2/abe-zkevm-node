set -x

shopt -s expand_aliases
alias geth="docker-compose exec -T zkevm-mock-l1-network geth"
alias gethL2="docker-compose exec -T zkevm-explorer-json-rpc /app/zkevm-node"
alias dc='docker-compose'

DATE=$(date +%Y%m%d-%H%M%S)

debug() {
    source .env
    NAME=b2-zkevm-node
    docker exec -it $NAME sh
    return
    docker run \
        --name $NAME \
        --entrypoint sleep \
        --volume /root/b2-node-single-client-all-data:/host \
        --detach \
        $B2_ZKEVM_NODE_IMAGE infinity
    return
    exec >"$FUNCNAME.log" 2>&1
    make stop-explorer
    make run-explorer
    sleep 1m
    NAME=zkevm-explorer-l2
    docker-compose exec -T $NAME env
    docker-compose logs $NAME | grep -iE --max-count=20 'error'
    return
}

e2e() {
    exec >"$FUNCNAME.log" 2>&1
    for num in {1..11}; do
        # echo "--- $num ---"
        make test-e2e-group-${num}
    done
}

jmeter-probe() {
    DIRNAME=tmp-jmeter-20231215-093244
    # wc $DIRNAME/*
    # FILE=e2e.log
    FLAG='-irnE'

    # grep $FLAG '=== RUN' $FILE
    # grep $FLAG '\-\-\- FAIL' $FILE
    # grep $FLAG '\-\-\- PASS' $FILE
    # grep $FLAG 'err|fail' $DIRNAME
    # grep $FLAG 'err|fail' $DIRNAME/* | wc
    # grep $FLAG 'err|fail' $DIRNAME/*
    # return
    # grep $FLAG 'err|fail' $DIRNAME/test-e2e-group-1-debug.log
    grep $FLAG 'err|fail' $DIRNAME/zkevm-mock-l1-network.log
    # grep $FLAG 'err|fail' $DIRNAME/zkevm-prover.log
    grep $FLAG 'err|fail' $DIRNAME/zkevm-sequence-sender.log
    grep $FLAG 'err|fail' $DIRNAME/zkevm-sequencer.log
    # grep $FLAG 'err|fail' $DIRNAME/zkevm-sync.log
    return
}

jmeter-debug() {
    # DIRNAME=tmp-jmeter-$DATE
    # mkdir -p $DIRNAME
    docker-compose down -v zkevm-pool-db
    docker-compose up -d zkevm-pool-db
    return
    dc ps
    svs=$(dc ps --services | xargs)
    for item in $svs;do
        dc exec -it $item date
        # dc exec -it $item env
        # dc exec -it $item cat /etc/os-release
        # dc logs $item >$DIRNAME/$item.log 2>&1
    done
}

addChainStateToB2Node() {
    set -e
    docker container rm -f b2-node
    B2_NODE_IMAGE=ghcr.io/b2network/b2-node:20231226-104117-9fd5727
    TMT_ROOT=/root/b2network/single-client-datadir
    cd $TMT_ROOT
    # bash helper.sh restore
    CHAIN_REPO_ID=$(git log -1 --format='%h')
    cd -
    docker run \
        --name b2-node \
        --entrypoint sleep \
        --volume $TMT_ROOT:/host \
        --detach \
        $B2_NODE_IMAGE infinity
    docker container ls
    docker exec -it b2-node sh -c 'mkdir -p /root/.ethermintd/ && cp -r /host/* /root/.ethermintd/ && ls /root/.ethermintd/'
    docker commit --author tony-armstrong b2-node $B2_NODE_IMAGE-with-datadir-$CHAIN_REPO_ID
    docker container stop b2-node
    docker container rm b2-node
    return
}
containers() {
    exec >"$FUNCNAME.log" 2>&1
    # docker-compose ps --all --format json >tmp-containers.json
    docker-compose ps --all
}

onlyProbeL2() {
    # exec > "$FUNCNAME.log" 2>&1
    gethL2 --help
    gethL2 run --help
    gethL2 version
}

onlyProbeL1() {
    exec >"$FUNCNAME.log" 2>&1

    # docker-compose --help
    # docker-compose down -v zkevm-mock-l1-network
    # docker-compose up -d zkevm-mock-l1-network
    # return

    # docker-compose exec -T zkevm-mock-l1-network uname -a
    geth --help
    geth version
    geth license
    return

    # docker-compose logs --help
    docker-compose logs \
        --no-log-prefix \
        --no-color \
        zkevm-mock-l1-network
    # --tail 10 \
}

collectionLog() {
    docker-compose logs \
        --timestamps \
        --since 2023-12-26T22:42:50 \
        --until 2023-12-26T22:52:50 \
        --no-color  > tmp.log
    for cmd in wc du head tail; do
        $cmd tmp.log
    done
    return
    DIRNAME=log-$DATE-reorgctx
    mkdir -p $DIRNAME
    docker-compose logs \
        --no-color > $DIRNAME/all.log
    for name in \
        zkevm-approve \
        zkevm-sync \
        zkevm-eth-tx-manager \
        zkevm-sequencer \
        zkevm-sequence-sender \
        zkevm-l2gaspricer \
        zkevm-aggregator \
        zkevm-json-rpc \
        zkevm-mock-l1-network \
        zkevm-prover; do
        docker-compose logs \
            --no-log-prefix \
            --no-color \
            $name >$DIRNAME/$name.log
    done

    tar -jcf /stable/work-backup/b2-network/b2-$DIRNAME.tar.bz2 $DIRNAME/*
}

init() {
    exec >"$FUNCNAME.log" 2>&1
    # docker exec --help
    psql --help
    return
    go version
    docker ps
    return
}

probe() {
    go test -count=1 -short -race -p 1 -covermode=atomic -coverprofile=../coverage.out -timeout 70s  -run TestAddAndGetByStatus ../ethtxmanager/
    # exec >"$FUNCNAME.log" 2>&1
    # grep -irE 'STATEDB.*:|POOLDB.*:|EVENTDB.*:|NETWORK' Makefile

    # export DATABASE_URL="postgres://l1_explorer_user:l1_explorer_password@192.168.50.127:5436/l1_explorer_db?sslmode=disable"
    # psql --echo-all $DATABASE_URL --file=zkevm-l1.sql
    return
    # export DATABASE_URL="postgres://pool_user:pool_password@192.168.50.127:5433/pool_db?sslmode=disable"
    # psql --echo-all $DATABASE_URL --file=zkevm-pool.sql

    export DATABASE_URL="postgres://state_user:state_password@192.168.50.127:5432/state_db?sslmode=disable"
    psql --echo-all $DATABASE_URL --file=zkevm-state.sql
    return
    export DATABASE_URL="postgres://event_user:event_password@192.168.50.127:5435/event_db?sslmode=disable"
    psql --echo-all $DATABASE_URL --file=zkevm-event.sql
    # psql --echo-all $DATABASE_URL --file=zkevm-event.sql --output=zkevm-event.log
    # psql --echo-hidden $DATABASE_URL --file=zkevm-event.sql --output=zkevm-event.log
}

tmp() {
    docker-compose stop zkevm-json-rpc
    docker-compose rm zkevm-json-rpc
    docker-compose up -d zkevm-json-rpc
    docker-compose logs -f zkevm-json-rpc

}

archiveStrace() {
    DATE=$(date +%Y%m%d-%H%M%S)
    FILES="strace-out/* *.log"
    tar -jcf zkevm-node-strace-$DATE.tar.bz2 $FILES
    # rm -rf $FILES
}

collectStrace() {
    exec >"$FUNCNAME.log" 2>&1
    make stop
    rm -rf strace-out/*
    make run

    sleep 20s
    cd /mnt/code/org-0xPolygonHermez/zkevm-contracts
    bash helper.sh probe
    cd -

    docker-compose ps -q | xargs docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'
    sleep 20s
    make stop
    return
}

probeStrace() {
    # exec >"$FUNCNAME.log" 2>&1
    cd strace-out
    # wc *
    # ls | xargs grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' | sort -u

    # grep -iorn 'input\\":\\"0x\w*' tmp.log | sort -u
    # grep -irn 'eth_\w*'  l1-filter-by-method.log
}

repoStatus() {
    for item in \
        /ssd/code/work/b2network/b2-zkevm-prover \
        /ssd/code/work/b2network/b2-zkevm-node \
        /ssd/code/work/b2network/b2-zkevm-contracts \
        /ssd/code/work/b2network/b2-node; do
        # git -C $item status
        # git -C $item branch
        git -C $item diff
    done
}

changeHost() {
    # toml set --help
    # return
    FILE=config/non-container-test.node.config.toml
    toml set --toml-path $FILE State.DB.Port 5432
    toml set --toml-path $FILE Pool.DB.Port 5433
    toml set --toml-path $FILE EventLog.DB.Port 5435
    toml set --toml-path $FILE HashDB.Port 5432
}

probeReorg(){
    # du -sh *
    # wc *
    # grep -irnc 'error' *
    # grep -irnc 'reorg' *
    # grep -irnc 'BatchNumber.*1' zkevm*
    grep -irn -m 65 'BatchNumber.*1' zkevm*
    # grep -irn fed2e021c9aedfddb4fbab5a143bd35549e4d1edc7d8866a3f8fa3fa3fbe8332 zkevm*
}

$@
