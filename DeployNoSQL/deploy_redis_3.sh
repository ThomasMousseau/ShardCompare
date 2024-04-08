#!/bin/bash

# Configuration
networkName="redis-cluster"
redisImage="redis:6.2.6"
numNodes=3  
iteration=1
folderLogs="redis_${numNodes}_nodes"
pathExe="/home/thomasm/ycsb-0.17.0" 
pathLogs="/home/thomasm/School/Poly-session-6/LOG8430/DeployNoSQL/${folderLogs}"
MAX_ITERATION=1

mkdir -p "${pathLogs}"

deploy_redis() {
    docker network create ${networkName}

    # Start Redis containers
    for i in $(seq 1 ${numNodes}); do
        docker run -d --name "redis${i}" --net ${networkName} ${redisImage} \
            redis-server --appendonly yes --cluster-enabled yes --cluster-config-file nodes.conf --cluster-node-timeout 5000 --bind 0.0.0.0
    done

    echo "Waiting 5 seconds for the containers to be ready..."
    sleep 5

    # Getting IP addresses for Redis nodes
    ips=$(for i in $(seq 1 ${numNodes}); do
        docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "redis${i}"
    done | xargs)

    # Initializing Redis cluster
    echo yes | docker run -i --rm --net ${networkName} ${redisImage} \
        redis-cli --cluster create ${ips// /:6379 } --cluster-replicas 1
    echo "Redis cluster has been initialized."
}

run_ycsb() {
   
    "${pathExe}/bin/ycsb.sh" load redis  -s -P "${pathExe}/workloads/workloada" -p "redis.host=127.0.0.1" -p "redis.port=6379" > "${pathLogs}/load_50_50_${iteration}.txt"
    "${pathExe}/bin/ycsb.sh" run redis  -s -P "${pathExe}/workloads/workloada" -p "redis.host=127.0.0.1" -p "redis.port=6379"> "${pathLogs}/run_50_50_${iteration}.txt"

    "${pathExe}/bin/ycsb.sh" load redis  -s -P "${pathExe}/workloads/workload_10_90" -p "redis.host=127.0.0.1" -p "redis.port=6379" > "${pathLogs}/load_10_90_${iteration}.txt"
    "${pathExe}/bin/ycsb.sh" run redis  -s -P "${pathExe}/workloads/workload_10_90" -p "redis.host=127.0.0.1" -p "redis.port=6379" > "${pathLogs}/run_10_90_${iteration}.txt"

    echo "This section needs to be adjusted based on YCSB's support for Redis."
}

delete_cluster() {
    docker rm -f $(docker ps -a -q --filter="name=redis")
    docker network rm ${networkName}
}

for iteration in $(seq 1 ${MAX_ITERATION}); do
    delete_cluster
    deploy_redis
    run_ycsb 
done

echo "End of script"
