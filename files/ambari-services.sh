#!/bin/bash

AMBARI_USER_NAME=$1
AMBARI_USER_PASSWORD=$2
AMBARI_WEB_SERVER=$3
AMBARI_CLUSTER_NAME=$4

  help() {
    echo $5
    echo "$0 [cmd] <args>"
    echo "list - show list of processes"
    echo "start [<process name>|all] - start the given process"
    echo "stop [<process name>|all] - stop the given process"
    exit 1
  }

  service() {
    if [ "$#" -lt 2 ]; then
      help "Illegal number of parameters"
    fi

    case "$5" in
      start)
        CMD=STARTED
        FILTER_ON="?ServiceInfo/state=INSTALLED"
        REQUEST_INFO="Starting"
        ;;
      stop)
        CMD=INSTALLED
        FILTER_ON="?ServiceInfo/state=STARTED"
        REQUEST_INFO="Stopping"
        ;;
      restart)
        CMD=RESTARTED
        FILTER_ON=""
        REQUEST_INFO="Restarting"
        ;;
      *)
        echo "Unrecognized option"
        exit 1
    esac

    # If the request is for "all" then pull information
    # for all services, rather than any particular one
    if [ $6 == "all" ]; then
      #SERVICE_NAME="$FILTER_ON"
      REQUEST_INFO="$REQUEST_INFO all services"
    else
      SERVICE_NAME="/$6"
    fi

    # Grab result for status polling
    RESULT=`curl -s -k -H "X-Requested-By: ambari" -X PUT -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} http://${AMBARI_WEB_SERVER}:8080/api/v1/clusters/$AMBARI_CLUSTER_NAME/services$SERVICE_NAME -d '{"RequestInfo":{"context":"'"$REQUEST_INFO"'"},"Body":{"ServiceInfo":{"state":"'$CMD'"}}}'`
    if [ $? -ne 0 ]; then
      echo "command failed: $RESULT"
      exit 1
    fi
   
    TASKID=`echo "$RESULT" | grep \"id\" | cut -d ":" -f 2 | tr -d "," | tr -d " "`

    if [ -z "$TASKID" ]; then 
      echo "Service may already be in the requested state"
      exit 0
    fi

    # Polls Ambari every 10 seconds via isStillRunning function
    # to confirm if current job has completed
    while isStillRunning $TASKID; do
      echo "Still processing request"
        sleep 10
    done
    echo "DONE"
    exit 0
  }

  list() {
    curl -s -k -H "X-Requested-By: ambari" -X GET -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} http://${AMBARI_WEB_SERVER}:8080/api/v1/clusters/$AMBARI_CLUSTER_NAME/services | grep service_name | tr -d " " | sed 's/\"//g' | cut -d ":" -f 2
    exit 0
  }

  # Get status of currently running TASKID
  function isStillRunning () {
    for x in `curl -s -k -H "X-Requested-By: ambari" -X GET -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} http://${AMBARI_WEB_SERVER}:8080/api/v1/clusters/$AMBARI_CLUSTER_NAME/requests/$1 | grep tasks | grep http`; do
      X=`echo ${x##*/} | egrep -v "href|:" | cut -d "\"" -f 1`
      B=`echo "$X" |  grep -v '^$'`
      if curl -s -k -H "X-Requested-By: ambari" -X GET -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} http://${AMBARI_WEB_SERVER}:8080/api/v1/clusters/$AMBARI_CLUSTER_NAME/requests/$1/tasks/$B?fields=Tasks/status | grep -v "http" | grep status | egrep "IN_PROGRESS|QUEUED|PENDING"; then
        return 0
      fi
      done
    return 1
  }

  # Assign or prompt for values if expected parameters
  # are not available at run time
  if [ "$#" -lt 1 ]; then
    help "Illegal number of parameters"
  fi

  if [ -z "${AMBARI_WEB_SERVER}" ]; then
    AMBARI_WEB_SERVER=http://127.0.0.1:8080
  fi

  if [ -z "${AMBARI_CLUSTER_NAME}" ]; then
    AMBARI_CLUSTER_NAME=ansiblecluster
  fi

  if [[ -z "${AMBARI_USER_NAME}" || -z "${AMBARI_USER_PASSWORD}" || -z "${AMBARI_CLUSTER_NAME}" ]]; then
    echo "Please enter Ambari login credentials"
    echo -n "Username: "
    read AMBARI_USER_NAME
    echo -n "Password: "
    read AMBARI_USER_PASSWORD
  fi

  case "$5" in
    start)
      service $*
      ;;
    stop)
      service $*
      ;;
    restart)
      service $*
      ;;
    list)
      list 
      ;;
    *)
      help "Unknown command: $5"
  esac
