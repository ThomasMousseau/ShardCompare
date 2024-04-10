#!/bin/bash

# Configuration
networkName="mongo-cluster"
replicaSetName="rs0"
mongoImage="mongo:4.4" 
numNodes=3  #! 3 ou 5
current_iteration=1
MAX_ITERATION=10
host_data_dir="/home/thomasm/School/Poly-session-6/LOG8430/DeployNoSQL/current_data"
container_data_dir="/usr/src/ycsb/data"


deploy_mongo() {
    docker network create ${networkName}

    # Démarrage des conteneurs MongoDB
    port=27017 
    for i in $(seq 1 ${numNodes}); do
        docker run -d --name "mongo${i}" -p ${port}:27017 --net ${networkName} \
            ${mongoImage} mongod --replSet ${replicaSetName} --bind_ip_all
        port=$((port+1))
    done

    echo "Attente de 5 secondes pour que les conteneurs soient prêts..."
    sleep 5

    # Construction de l'URI de connexion à MongoDB
    # port=27017 
    # mongodb_uri="mongodb://"
    # for i in $(seq 1 ${numNodes}); do
    #     mongodb_uri+="mongo${i}:27017,"
    #     port=$((port+1))
    # done
    # mongodb_uri=${mongodb_uri%,}/ycsb?replicaSet=${replicaSetName}"&w=1"

    docker exec -ti mongo1 mongo --eval "rs.initiate({
      _id: '${replicaSetName}',
      members: [
        $(for i in $(seq 1 ${numNodes}); do echo "{ _id: $((i-1)), host: 'mongo${i}:27017' },"; done | sed '$s/,$//')
      ]
    })"
    echo "L'ensemble de réplicas MongoDB a été initialisé."
}

run_ycsb() {

    mongodb_uri="mongodb://mongo1:27017/ycsb?replicaSet=rs0&w=1"
    #mongodb_uri="mongodb://mongo1:27017/ycsb?w=1" #!they all work
    #mongodb_uri="mongodb://mongo1:27017,mongo2:27017,mongo3:27017/ycsb?replicaSet=rs0&w=1" #!they all work

    # ./bin/ycsb.sh load mongodb -s -P workloads/workload_10_90 -p \"mongodb.url=${mongodb_uri}\" > data/load_10_90_${current_iteration}.txt;
    # ./bin/ycsb.sh run mongodb -s -P workloads/workload_10_90 -p \"mongodb.url=${mongodb_uri}\" > data/run_10_90_${current_iteration}.txt;"

    current_data_dir="${host_data_dir}/${current_iteration}"

    mkdir -p ${current_data_dir}

    docker run -d --name "ycsb${current_iteration}" --network ${networkName} -v "${current_data_dir}:/usr/src/ycsb/data" thomasmousseau/ycsb-0.17.0:latest /bin/sh -c "

    mkdir data; 

    ./bin/ycsb.sh load mongodb -s -P workloads/workloada -p \"mongodb.url=${mongodb_uri}\" > data/load_50_50_${current_iteration}.txt;
    ./bin/ycsb.sh run mongodb -s -P workloads/workloada -p \"mongodb.url=${mongodb_uri}\" > data/run_50_50_${current_iteration}.txt;"
    
    docker wait "ycsb${current_iteration}"

    #tail -f /dev/null"
}

delete_cluster() {
    docker rm -f $(docker ps -a -q --filter="name=mongo")
    docker rm -f $(docker ps -a -q --filter="name=ycsb")
    docker network rm ${networkName}
}

for current_iteration in $(seq 1 ${MAX_ITERATION}); do
    delete_cluster
    deploy_mongo
    run_ycsb
done

echo "Fin du script"