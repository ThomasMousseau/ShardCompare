#!/bin/bash

# Configuration
network_name="redis-replication"
redis_image="redis:6.2.5" #redis:7.2.3
num_slave_nodes=2  #! 2 ou 4
current_iteration=1
host_data_dir="/home/thomasm/School/Poly-session-6/LOG8430/DeployNoSQL/current_data"
MAX_ITERATION=10

name=("redis-master" "redis-slave1" "redis-slave2")

deploy_redis() {

    docker network create ${network_name}
    
    #Start Redis containers
    docker run -d \
    --name ${name[0]} \
    --network $network_name \
    -p 6379:6379 \
    $redis_image \
    redis-server --appendonly yes --bind 0.0.0.0

    for i in $(seq 1 $num_slave_nodes); do
    #echo "Starting Redis slave $i && ${name[i]}"
    docker run -d --name redis-slave${i} --network ${network_name} ${redis_image} \
        redis-server --slaveof redis-master 6379 --appendonly yes --bind 0.0.0.0
    done

}

run_ycsb() {

    current_data_dir="${host_data_dir}/${current_iteration}"

    mkdir -p ${current_data_dir}

    #./bin/ycsb.sh load redis -s -P workloads/workloada -p "redis.host=172.29.0.2" -p "redis.port=6379"

    # ./bin/ycsb.sh load redis -s -P workloads/workloada -p \"redis.host=${redis_master_ip}\" -p \"redis.port=6379\" > data/load_50_50_${current_iteration}.txt;
    # ./bin/ycsb.sh run redis -s -P workloads/workloada -p \"redis.host=${redis_master_ip}\" -p \"redis.port=6379\" > data/run_50_50_${current_iteration}.txt;"

    #redis-master
    redis_master_ip=$(docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "redis-master")
    echo "Redis master IP: ${redis_master_ip}"

    docker run -d --name "ycsb${current_iteration}" --network ${network_name} -v "${current_data_dir}:/usr/src/ycsb/data" thomasmousseau/ycsb-0.17.0:latest /bin/sh -c "

    mkdir data; 

    ./bin/ycsb.sh load redis -s -P workloads/workload_10_90 -p \"redis.host=${redis_master_ip}\" -p \"redis.port=6379\" > data/load_10_90_${current_iteration}.txt;
    ./bin/ycsb.sh run redis -s -P workloads/workload_10_90 -p \"redis.host=${redis_master_ip}\" -p \"redis.port=6379\" > data/run_10_90_${current_iteration}.txt;"
    docker wait "ycsb${current_iteration}"

    #tail -f /dev/null"

}

delete_cluster() {
    docker rm -f $(docker ps -a -q --filter="name=redis")
    docker rm -f $(docker ps -a -q --filter="name=ycsb")
    docker network rm ${network_name}
}

for current_iteration in $(seq 1 ${MAX_ITERATION}); do
    delete_cluster
    deploy_redis
    run_ycsb 
done

echo "End of script"
