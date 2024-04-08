#!/bin/bash

# Configuration

#!Le script doit etre effectuer dans le dossier ycsb (/home/thomasm/ycsb-0.17.0)
networkName="mongo-cluster"
replicaSetName="rs0"
mongoImage="mongo"
numNodes=3 
iteration=1
folderLogs="mongo_${numNodes}_nodes"
pathExe="/home/thomasm/ycsb-0.17.0"
pathLogs="/home/thomasm/School/Poly-session-6/LOG8430/DeployNoSQL/${folderLogs}" 
MAX_ITERATION=4

mkdir -p ${pathLogs}

delete_cluster()
{
  docker rm -f $(docker ps -a -q --filter="name=mongo")
  docker network rm ${networkName}
}

delete_cluster

deploy_mongo()
{
  docker network create ${networkName}

  # Démarrage des conteneurs MongoDB
  for i in $(seq 1 ${numNodes}); do
      docker run -d --name "mongo${i}" --net ${networkName} \
          ${mongoImage} mongod --replSet ${replicaSetName}
  done

  # Attendez que les conteneurs soient prêts
  echo "Attente de 10 secondes pour que les conteneurs soient prêts..."
  sleep 10

 # Utiliser un conteneur mongo séparé pour la configuration de l'ensemble de réplicas
  docker run --rm --net ${networkName} mongo:4.4 mongo --host mongo1 --eval "rs.initiate({
    _id: '${replicaSetName}',
    members: [
      $(for i in $(seq 1 ${numNodes}); do echo "{ _id: $((i-1)), host: 'mongo${i}:27017' },"; done | sed '$s/,$//')
    ]
  })"

  echo "L'ensemble de réplicas MongoDB a été initialisé."

  # Afficher l'état de l'ensemble de réplicas
  echo "État de l'ensemble de réplicas :"
  docker run --rm --net ${networkName} mongo:4.4 mongo --host mongo1 --eval "rs.status()"

}

run_ycsb()
{
  
  touch "${pathLogs}/load_50_50_${iteration}.txt"
  touch "${pathLogs}/run_50_50_${iteration}.txt"

  "${pathExe}/bin/ycsb.sh" load mongodb -s -P "${pathExe}/workloads/workloada" > "${pathLogs}/load_50_50_${iteration}.txt"
  "${pathExe}/bin/ycsb.sh" run mongodb -s -P "${pathExe}/workloads/workloada" > "${pathLogs}/run_50_50_${iteration}.txt"

  touch "${pathLogs}/load_90_10_${iteration}.txt"
  touch "${pathLogs}/run_90_10_${iteration}.txt"

  "${pathExe}/bin/ycsb.sh" load mongodb -s -P "${pathExe}/workloads/workload_10_90" > "${pathLogs}/load_10_90_${iteration}.txt"
  "${pathExe}/bin/ycsb.sh" run mongodb -s -P "${pathExe}/workloads/workload_10_90" > "${pathLogs}/run_10_90_${iteration}.txt"
}



for iteration in $(seq 1 ${MAX_ITERATION}); do
    deploy_mongo
    run_ycsb
    delete_cluster
done


echo "Fin du script"





