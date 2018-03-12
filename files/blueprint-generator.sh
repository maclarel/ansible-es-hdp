#!/bin/bash

# Only taking the first value of master. The other 
# master nodes will have Ambari agents, but
# if services are wanted, they should be provisioned
# in Ambari manually
MASTER=`echo $1 | awk '{print $1}'`
COMPUTE=$2
STREAM=$3
AMBARI_USER_PASSWORD=$4
AMBARI_HOSTMAPPING_FILE="/tmp/hostmapping_file.json"
AMBARI_BLUEPRINT_FILE="/tmp/ambari_blueprint.json"
BLUEPRINT_NAME=`basename $AMBARI_BLUEPRINT_FILE | sed 's/.json//'`

BLUEPRINT_TEMPLATE=/tmp/blueprint_template.json

# Error checking, we need one of each Compute, Stream and Master as a minimum
if [ -z "$MASTER" ]; then
  echo There needs to be atleast one master node
  exit 1
elif [ -z "$COMPUTE" ]; then
  echo There needs to be atleast one compute node
  exit 1
elif [ -z "$STREAM" ]; then
  echo There needs to be atleast one stream node
  exit 1
elif [ -z "$AMBARI_USER_PASSWORD" ]; then
  echo There was no password specified
  exit 1
fi

generate_host_list () {
  HOST_STRING='{ "name" : "'"$1"'", "hosts" : ['
  for x in $2; do
    HOST_STRING=$HOST_STRING'{"fqdn" : "'"${x}"'"},'
  done
  echo "${HOST_STRING/%,/}"']}'
}

# Output host mapping
echo '{
  "blueprint" : "'${BLUEPRINT_NAME}'",
  "default_password" : "'${AMBARI_USER_PASSWORD}'",
  "provision_action" : "INSTALL_ONLY",
  "host_groups" : [
' > "$AMBARI_HOSTMAPPING_FILE"

# We need configure the hosts file correctly for the number of hosts.  
ALL_AMBARI_AGENTS=`echo $COMPUTE $MASTER $ANALYTICS $STREAM | tr " " "\n" |  sort -u`
NUM_AMBARI_AGENTS=`echo $ALL_AMBARI_AGENTS | wc -w`
# If we have only two hosts then we need to compat the setup.
if [ $NUM_AMBARI_AGENTS -eq 1 ]; then
  echo "     "`generate_host_list "host_group_master" "$MASTER"` >> "$AMBARI_HOSTMAPPING_FILE"
  echo '  ]
  }' >> "$AMBARI_HOSTMAPPING_FILE"
elif [ $NUM_AMBARI_AGENTS -eq 2 ]; then
  echo "     "`generate_host_list "host_group_master" "$MASTER"`, >> "$AMBARI_HOSTMAPPING_FILE"
  echo "     "`generate_host_list "host_group_compute" "$COMPUTE"` >> "$AMBARI_HOSTMAPPING_FILE"
  echo '  ]
  }' >> "$AMBARI_HOSTMAPPING_FILE" 
else
  echo "     "`generate_host_list "host_group_master" "$MASTER"`, >> "$AMBARI_HOSTMAPPING_FILE"
  echo "     "`generate_host_list "host_group_compute" "$COMPUTE"`, >> "$AMBARI_HOSTMAPPING_FILE"
  echo "     "`generate_host_list "host_group_stream" "$STREAM"` >> "$AMBARI_HOSTMAPPING_FILE"
  echo '  ]
  }' >> "$AMBARI_HOSTMAPPING_FILE" 
fi

generate_group_list () {
  GROUP_STRING='{ "components" : ['
  IFS=","
  for x in $2; do
    unset IFS
    GROUP_STRING="${GROUP_STRING}"'{ "name" : "'"${x}"'"},'
  done
  GROUP_STRING="${GROUP_STRING/%,/}"
  GROUP_STRING="${GROUP_STRING}"'],'
  GROUP_STRING="${GROUP_STRING}"'"configurations" : [ ],'
  GROUP_STRING="${GROUP_STRING}"'"name" : "'"$1"'",'
  GROUP_STRING="${GROUP_STRING}"'"cardinality" : "1"}'

  echo "${GROUP_STRING}"
}

# Output blueprint
STREAM_COMPONENTS=SPARK_CLIENT,YARN_CLIENT,HDFS_CLIENT,METRICS_MONITOR,SUPERVISOR,INFRA_SOLR_CLIENT,TEZ_CLIENT,ZOOKEEPER_CLIENT,HCAT,PIG,KAFKA_BROKER,MAPREDUCE2_CLIENT,SLIDER,HBASE_CLIENT,FLUME_HANDLER,HIVE_CLIENT
COMPUTE_COMPONENTS=NODEMANAGER,HBASE_REGIONSERVER,DATANODE,METRICS_MONITOR
MASTER_COMPONENTS=HIVE_SERVER,METRICS_MONITOR,INFRA_SOLR_CLIENT,HBASE_MASTER,HIVE_METASTORE,TEZ_CLIENT,ZOOKEEPER_CLIENT,HCAT,WEBHCAT_SERVER,SECONDARY_NAMENODE,SLIDER,ZOOKEEPER_SERVER,DRPC_SERVER,METRICS_COLLECTOR,METRICS_GRAFANA,SPARK_CLIENT,YARN_CLIENT,HDFS_CLIENT,MYSQL_SERVER,STORM_UI_SERVER,HISTORYSERVER,NAMENODE,NIMBUS,PIG,MAPREDUCE2_CLIENT,HBASE_CLIENT,INFRA_SOLR,SPARK_JOBHISTORYSERVER,APP_TIMELINE_SERVER,HIVE_CLIENT,RESOURCEMANAGER

# We need to fix up the template file with the correct setup based on number of available systems.
if [ $NUM_AMBARI_AGENTS -eq 1 ]; then
  sed 's/host_group_compute/host_group_master/g; s/host_group_stream/host_group_master/g' "${BLUEPRINT_TEMPLATE}" > "${AMBARI_BLUEPRINT_FILE}"
  CONFIGURATION_STRING=`generate_group_list "host_group_master" "${MASTER_COMPONENTS},${COMPUTE_COMPONENTS},${STREAM_COMPONENTS}"`
elif [ $NUM_AMBARI_AGENTS -eq 2 ]; then
  sed 's/host_group_stream/host_group_master/g' "${BLUEPRINT_TEMPLATE}" > "${AMBARI_BLUEPRINT_FILE}"
  CONFIGURATION_STRING=`generate_group_list "host_group_master" "${MASTER_COMPONENTS},${STREAM_COMPONENTS}"`,
  CONFIGURATION_STRING="${CONFIGURATION_STRING}"`generate_group_list "host_group_compute" "${COMPUTE_COMPONENTS}"`
else
  CONFIGURATION_STRING=`generate_group_list "host_group_master" "${MASTER_COMPONENTS}"`,
  CONFIGURATION_STRING="${CONFIGURATION_STRING}"`generate_group_list "host_group_compute" "${COMPUTE_COMPONENTS}"`,
  CONFIGURATION_STRING="${CONFIGURATION_STRING}"`generate_group_list "host_group_stream" "${STREAM_COMPONENTS}"`
fi

sed 's/@HOSTGROUPS/'"${CONFIGURATION_STRING}"'/' "${BLUEPRINT_TEMPLATE}" > "${AMBARI_BLUEPRINT_FILE}"