#!/bin/bash

SERVICE=$1
USERS=$2
FILE="${SERVICE}.py"
HOST="http://localhost:8081"

locust -f $FILE --host ${HOST} --users ${USERS} --spawn-rate ${USERS} --csv profiling-${SERVICE}-${USERS} --csv-full-history
