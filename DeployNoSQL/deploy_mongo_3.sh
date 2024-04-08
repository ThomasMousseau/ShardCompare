#!/bin/bash

# Configuration
networkName="mongo-cluster"
replicaSetName="rs0"
mongoImage="mongo"
numNodes=3  #! A changer de 3 à 5
iteration=1
folderLogs="mongo_${numNodes}_nodes"
pathExe="/home/thomasm/ycsb-0.17.0"
pathLogs="/home/thomasm/School/Poly-session-6/LOG8430/DeployNoSQL/${folderLogs}"
MAX_ITERATION=1

mkdir -p "${pathLogs}"


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
    port=27017 
    mongodb_uri="mongodb://"
    for i in $(seq 1 ${numNodes}); do
        #mongodb_uri+="mongo${i}:27017,"
        mongodb_uri+="localhost:${port},"
        port=$((port+1))
    done
    mongodb_uri=${mongodb_uri%,}/ycsb?replicaSet=${replicaSetName}"&w=1"

    # Configuration des repliques MongoDB
    docker run --rm --net ${networkName} mongo:4.4 mongo --host mongo1 --eval "rs.initiate({
      _id: '${replicaSetName}',
      members: [
        $(for i in $(seq 1 ${numNodes}); do echo "{ _id: $((i-1)), host: 'mongo${i}:27017' },"; done | sed '$s/,$//')
      ]
    })"
    echo "L'ensemble de réplicas MongoDB a été initialisé."
}

run_ycsb() {
    if [ -z "${mongodb_uri}" ]; then
        echo "uri is empty"
        return 1
    fi

    #mongodb_uri="mongodb://localhost:27017/ycsb?replicaSet=rs0&w=1"

    echo "URI: ${mongodb_uri}"
    "${pathExe}/bin/ycsb.sh" load mongodb  -s -P "${pathExe}/workloads/workloada" -p "mongodb.url=${mongodb_uri}" > "${pathLogs}/load_50_50_${iteration}.txt"
    "${pathExe}/bin/ycsb.sh" run mongodb  -s -P "${pathExe}/workloads/workloada" -p "mongodb.url=${mongodb_uri}" > "${pathLogs}/run_50_50_${iteration}.txt"

    "${pathExe}/bin/ycsb.sh" load mongodb  -s -P "${pathExe}/workloads/workload_10_90" -p "mongodb.url=${mongodb_uri}" > "${pathLogs}/load_10_90_${iteration}.txt"
    "${pathExe}/bin/ycsb.sh" run mongodb  -s -P "${pathExe}/workloads/workload_10_90" -p "mongodb.url=${mongodb_uri}" > "${pathLogs}/run_10_90_${iteration}.txt"
}

delete_cluster() {
    docker rm -f $(docker ps -a -q --filter="name=mongo")
    docker network rm ${networkName}
}

for iteration in $(seq 1 ${MAX_ITERATION}); do
    delete_cluster
    deploy_mongo
    run_ycsb
done

echo "Fin du script"
