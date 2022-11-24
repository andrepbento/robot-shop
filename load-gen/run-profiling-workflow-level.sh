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

# LOADS=(1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800 900 1000 1200 1500 1800 2000 2500 3000 5000 4000 6000 7000 8000 9000 10000 15000 20000 25000 30000 35000 40000)
WORKFLOWS=(2)
# LOADS=(1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 200 300 400 500 600 700 800 900 1000) # TODO: 1st run
# LOADS=(1200 1500 1800 2000)
# LOADS=(2500 3000 5000 4000 6000 7000 8000 9000 10000 15000 20000 25000 30000 35000 40000) # TODO: 2nd run
LOADS=(120 140 160 180 220 240 260 280 320 340 360 380 500)
# LOADS=(120 140 160 180 220 240 260 280 320 340 360 380 420 440 460 480 520 540 560 580) # TODO: Run with WORKFLOWS=(1)
# LOADS=(1 2 3 4 5 6 7 8 9 10 20 30 40 50 60 70 80 90 100 120 140 160 180 200) # TODO: Run with WORKFLOWS=(3)
RUN_TIME=90
SLEEP=10
NAMESPACE="robot-shop"
WORKERS="16"

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

DEPLOYMENTS="cart catalogue dispatch payment ratings shipping user web"
enable_autoscaler() {
    for DEP in $DEPLOYMENTS; do
        kubectl -n $NAMESPACE autoscale deployment $DEP --max 32 --min 1 --cpu-percent 80
    done

    echo "Waiting ${SLEEP} seconds for changes to apply autoscaler configuration..."
    sleep $SLEEP
    kubectl -n $NAMESPACE get hpa
}

disable_autoscaler() {
    for DEP in $DEPLOYMENTS; do
        kubectl -n $NAMESPACE delete hpa $DEP
    done

    echo "Waiting ${SLEEP} seconds for changes to apply autoscaler configuration..."
    sleep $SLEEP
    kubectl -n $NAMESPACE get hpa
}

monitor_data_pid=0
start_collecting_monitor_data() {
    cd ~/robot-shop/load-gen

    workflow=$1
    load=$2

    MONITOR_OUT="${OUT_DIR}/profiling-${ID}-wf-${workflow}-${load}-monitoring.json"
    printf "Monitor data output file: %s\n" ${MONITOR_OUT}

    while true; do
        sleep 10
        kubectl get hpa -n ${NAMESPACE} -o json >>$MONITOR_OUT
    done &

    monitor_data_pid=$!
    printf "Monitor data collector pid: %s\n" ${monitor_data_pid}
}

stop_collecting_monitor_data() {
    kill -9 $monitor_data_pid
    printf "Monitor data collector with pid: %s killed\n" ${monitor_data_pid}
}

run_load() {
    workflow=$1
    load=$2

    OUT="${OUT_DIR}/locust-profiling-${ID}-wf-${workflow}.csv"
    printf "Output file: %s\n" ${OUT}

    printf "Running load for workflow %s, with load %s\n" ${workflow} ${load}

    cd ~/robot-shop/load-gen

    for ((w = 1; w <= $WORKERS; w++)); do
        printf "Starting worker %s\n" $w
        WORKFLOW=${workflow} RUN_TIME=${RUN_TIME} LOAD=${load} OUT=${OUT} locust -f robot-shop-wf-${workflow}.py --worker &
    done

    SERVICE_PORT=$(kubectl get svc -n robot-shop -o go-template='{{range .items}}{{range.spec.ports}}{{if .nodePort}}{{.nodePort}}{{"\n"}}{{end}}{{end}}{{end}}')
    printf "Service port: %s\n" ${SERVICE_PORT}
    ADDRESS="${MINIKUBE_IP}:${SERVICE_PORT}"
    printf "Address: %s\n" ${ADDRESS}
    printf "Host: %s" "http://${ADDRESS}/"

    WORKFLOW=${workflow} RUN_TIME=${RUN_TIME} LOAD=${load} OUT=${OUT} locust -f robot-shop-wf-${workflow}.py --host http://${ADDRESS}/ --users ${load} --spawn-rate ${load} --run-time ${RUN_TIME}s --headless --master --expect-workers=${WORKERS}
    #--csv ${service}_${REPLICAS}_${load} --csv-full-history

    sleep $SLEEP

    pkill locust
}

for workflow in ${WORKFLOWS[*]}; do
    OUT_DIR="./autoscaler-wf${workflow}"
    mkdir ${OUT_DIR}
    for load in ${LOADS[*]}; do
        re_deploy_robot_shop

        enable_autoscaler

        printf "Profiling workflow %s with %s load\n" ${workflow} ${load}

        start_collecting_monitor_data ${workflow} ${load}

        run_load ${workflow} ${load}

        stop_collecting_monitor_data

        disable_autoscaler
    done
done

printf "Deleting %s\n" ${NAMESPACE}
kubectl delete ns ${NAMESPACE}

printf "Profilling finished\n"
