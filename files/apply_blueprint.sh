#!/bin/bash

AMBARI_USER_NAME=$1
AMBARI_USER_PASSWORD=$2
AMBARI_WEB_SERVER=$3
AMBARI_HOSTMAPPING_FILE="/tmp/hostmapping_file.json"
AMBARI_BLUEPRINT_FILE="/tmp/ambari_blueprint.json"
BLUEPRINT_NAME=`basename $AMBARI_BLUEPRINT_FILE | sed 's/.json//'`

sed -i '/blueprint/s/:.*,/: "'${BLUEPRINT_NAME}'",/' ${AMBARI_HOSTMAPPING_FILE} 

RESULT=`curl -s -H "X-Requested-By: ambari" -X POST -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} ${AMBARI_WEB_SERVER}:8080/api/v1/blueprints/${BLUEPRINT_NAME} -d@${AMBARI_BLUEPRINT_FILE}`
echo $RESULT

if echo ${RESULT} | grep 'Attempted to create a Blueprint which already exists'; then
  echo "blueprint already exists, removing it and trying again"
  curl -s -H "X-Requested-By: ambari" -X DELETE -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} ${AMBARI_WEB_SERVER}:8080/api/v1/blueprints/${BLUEPRINT_NAME}
  RESULT=`curl -s -H "X-Requested-By: ambari" -X POST -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} ${AMBARI_WEB_SERVER}:8080/api/v1/blueprints/${BLUEPRINT_NAME} -d@${AMBARI_BLUEPRINT_FILE}`
fi

if echo ${RESULT} | grep '"status"' ; then
  echo "Failed to upload blueprint"
  exit 1
fi

RESULT=`curl -H "X-Requested-By: ambari" -X POST -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} ${AMBARI_WEB_SERVER}:8080/api/v1/clusters/${AMBARI_CLUSTER_NAME} -d@${AMBARI_HOSTMAPPING_FILE}`

echo CMD: curl -H \"X-Requested-By: ambari\" -X POST -u ${AMBARI_USER_NAME}:${AMBARI_USER_PASSWORD} ${AMBARI_WEB_SERVER}:8080/api/v1/clusters/${AMBARI_CLUSTER_NAME} -d@${AMBARI_HOSTMAPPING_FILE}

if ! echo $RESULT | grep '"status" : "Accepted"'; then
  echo $RESULT
  echo "Failed to create cluster"
  exit 1
fi
