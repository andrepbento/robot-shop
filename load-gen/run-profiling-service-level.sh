#!/bin/bash

whoami

if [[ -z "$1" ]]; then
    echo "Argument 1 should be the ID of the run" 1>&2
    exit 1
fi

MINIKUBE_IP=$(minikube ip)
printf "Minikube ip: %s\n" ${MINIKUBE_IP}
ID=$1
printf "Run ID: %s\n" ${ID}
OUT="profiling-${ID}.csv"
printf "Output file: %s\n" ${OUT}

#SERVICES=("catalogue" "ratings" "shipping" "user" "web")
SERVICES=("cart")
REPLICAS=(4)
#LOADS=(1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90)
#LOADS=(100 200 300 400 500 600 700 800 900 1000 1200 1500 1800 2000 2500 3000 5000)
#LOADS=(4000 6000 7000 8000 9000 10000)
#LOADS=(15000 20000 25000 30000 35000 40000)
LOADS=(1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800 900 1000 1200 1500 1800 2000 2500 3000 5000)
RUN_TIME=90
SLEEP=10
NAMESPACE="robot-shop"
WORKERS="16"

scale_service() {
    service=$1
    replicas=$2
    
    printf "Scaling service %s to %s replicas\n" ${service} ${replicas}

    kubectl scale --replicas=${replicas} deploy ${service} -n ${NAMESPACE}
    while [[ $(kubectl -n ${NAMESPACE} get deploy ${service} -o 'jsonpath={..status.conditions[?(@.type=="Available")].status}') != "True" ]]; do
        printf "Service not available with %s replicas\n" ${replicas}
        sleep 10
    done
    printf "Service %s scaled to %s replicas\n" ${service} ${replicas}
}

run_load() {
    service=$1
    replicas=$2
    load=$3

    printf "Running load for service %s, with %s replicas, and load %s\n" ${service} ${replicas} ${load}

    cd ~/robot-shop/load-gen

    for (( w=1; w<=$WORKERS; w++ ))
    do
        printf "Starting worker %s\n" $w
        SERVICE=${service} REPLICAS=${replicas} RUN_TIME=${RUN_TIME} LOAD=${load} OUT=${OUT} locust -f robot-shop-${service}.py --worker &
    done

    SERVICE_PORT=$(kubectl get svc -n robot-shop -o go-template='{{range .items}}{{range.spec.ports}}{{if .nodePort}}{{.nodePort}}{{"\n"}}{{end}}{{end}}{{end}}')
    printf "Service port: %s\n" ${SERVICE_PORT}
    ADDRESS="${MINIKUBE_IP}:${SERVICE_PORT}"
    printf "Address: %s\n" ${ADDRESS}
    printf "Host: %s" "http://${ADDRESS}/"

    SERVICE=${service} REPLICAS=${replicas} RUN_TIME=${RUN_TIME} LOAD=${load} OUT=${OUT} locust -f robot-shop-${service}.py --host http://${ADDRESS}/ --users ${load} --spawn-rate ${load} --run-time ${RUN_TIME}s --headless --master --expect-workers=${WORKERS}
    #--csv ${service}_${REPLICAS}_${load} --csv-full-history 

    sleep $SLEEP

    pkill locust
}

re_deploy_robot_shop() {
    printf "Deleting %s\n" ${NAMESPACE}
    kubectl delete ns ${NAMESPACE}
    
    printf "Deploying %s\n" ${NAMESPACE}
    cd ~/robot-shop/K8s/helm
    kubectl create ns ${NAMESPACE}
    kubectl label namespace ${NAMESPACE} istio-injection=enabled --overwrite
    kubectl get namespace -L istio-injection # Check if istio-injection is enabled
    helm install robot-shop --namespace ${NAMESPACE} . --wait
}

for service in ${SERVICES[*]}
do
    for replicas in ${REPLICAS[*]}
    do
        for load in ${LOADS[*]}
        do
            re_deploy_robot_shop

            printf "Profiling service %s with %s replicas and %s load\n" ${service} ${replicas} ${load}

            scale_service ${service} ${replicas}
            
            run_load ${service} ${replicas} ${load}
        done
    done

    scale_service ${service} 1

    printf "Profilling service %s finished\n" ${service}

done

printf "Deleting %s\n" ${NAMESPACE}
kubectl delete ns ${NAMESPACE}

printf "Profilling finished\n"
