# README

## Disclaimer

This is adapted from other projects and as such likely has some gaps. Zero guarantees are provided that these playbooks (or end to end configuration) function as expected, and this is provided purely as-is.

## Requirements for the Installer

All servers must have Python 2.6+ installed. This can be run from any Red Hat based Linux distribution, or Mac OSX. If desired, the underlying Ansible playbooks can be run independently from any platform supported by Ansible.

If the installer is being run from Mac OSX, Ansible 2.2+ must be installed as a prerequisite (http://docs.ansible.com/ansible/intro_installation.html#latest-releases-on-mac-osx).

This assumes you have a mirror available that hosts repositories for Ambari/Elasticsearch/HDP/HDP Utils. If you do not, simply modify repos.yml to include the full URLs you wish to use.

`username` in all playbooks should be replaced with the user you wish to use.

# Configuring the Installer

These playbooks are designed to greatly reduce the amount of work required to deploy an HDP and/or Elasticsearch cluster. With this in mind, a majority of the configuration parameters that are required are automatically populated.

In this case, the `config` file must have the following variables populated:

 - AMBARI
   - This section should contain the hostname of the Ambari node, e.g.
	```
	[ambari]
	ambari.domain.com
	```

 - COMPUTE
   - This section should contain the hostnames of the Hadoop Worker nodes (HBase Region Server/HDFS Data Node/Storm Supervisor/YARN Node Manager/etc...), e.g.
	```
	[compute]
	compute1.domain.com
	compute2.domain.com
	compute3.domain.com
	compute4.domain.com
	compute5.domain.com
	```
 - STREAM
   - This section should contain the hostnames of the Kafka/Flume nodes, e.g.
	```
	[stream]
	stream1.domain.com
	stream2.domain.com
	stream3.domain.com
	```
 - SEARCH
   - This section should contain the hostnames of the Elasticsearch nodes, e.g.
	```
	[search]
	search1.domain.com
	search2.domain.com
	search3.domain.com
	```
 - MASTER
   - This section should contain the hostnames of the master nodes (HDFS Name Node/HBase Master/Storm Nimbus/etc...), e.g.
	```
	[master]
	master1.domain.com
	master2.domain.com
	master3.domain.com
	```

- There is a section entitled "[allServers:vars]" that contains basic configuration information. 
	- The `repo` variable should be updated to point to your local mirror of the required repositories, e.g.
	```
	[allServers:vars]
	repo="http://repo.yourcompany.com"
	```

# Running the Installer
The installer can be run in the following fashion:

`./install.sh`

When the installer is launched it will confirm whether or not the current user has ssh access to all remote nodes as the `username` user without needing a password. If a password is required, it will prompt you for one, and configure public key based access so future passwords are not required.

From the installation prompt, you can select to do a full product installation (e.g. options `1` and `2`), or to install/reinstall an individual component (options `2` through `6`), and finally an option to quit (`q`). 

In the event that a failure is encountered during a task, the installer will provide relevant diagnostic information. The install can be resumed directly from the failed task by selecting option `r` and entering the name of the failed task. For example, if the installation fails on "Install Ambari Server", you could select option `r` and enter "Install Ambari Server" at the prompt, and the installation would retry the installation starting from the "Install Ambari Server" task.

# Notes
- Once the installation is complete, I strongly recommends changing the password for the `username` user on all machines. This will not impact operation of the system.
- With the current release, only the first Master node specified will have services assigned to it in Ambari. This is to prevent duplicate (critical) services from being applied by means of Ambari Blueprints. A future release will support automation configuration of multiple Master role servers within Ambari. At this time if additional Master services are required, they should be manually provisioned/moved to the desired servers within Ambari.

# Additional Variables

Additional variables can be set in the files under the `group_vars` directory. The filenames correspdond to the groups of servers specified in the `config` file, for example variables for `master` nodes are in the `group_vars/master` file.

- allServers
	- Note that this file contains variables that are used across _all_ servers, hence the name.
	- `user_pass` - If you have changed the password for the `username` user, but still wish to make use of the installer, the new password must be specified here.

- allSearch
	- Note that this file contains variables that are used across both Search and Reporting nodes due to our use case for Elasticsearch.
	- `es_yml` - This specifies the path to elasticsearch.yml. If this is different on your system, it should be set here.
	- `es_cluster_name` - This specifies the name of the cluster you wish to create in Elasticsearch.
	- `es_master_count` - Calculation to determine the number of search nodes in the environment. This should not be changed.
	- `es_min_masters` - Calculation to determine the minimum number of master nodes required for operation to avoid "split-brain". This should not be changed without direct supervision.
	- `es_heap_size` - Calculation to determine "optimal" heap size for Elasticsearch. If the server has > 60GB of RAM, this will be set to 30GB, otherwise it will be set to roughly 50% of available RAM, minus 1GB.

- ambari
	- `AMBARI_USER_NAME` - Specifies the name of the administrator user to access Ambari. Default "admin".
	- `AMBARI_USER_PASSWORD` - Specifies the password for the administrator user to access Ambari. Default "admin".
	- `AMBARI_CLUSTER_NAME` - Specifies the name of the cluster configured within Ambari. Default "admin".

- master
	- `zk_hosts` - This combines all of the master node hostnames for use as the ZooKeeper list for Phoenix connections. This should not be changed.
	- `broker_list` - This combines all of the stream node hostnames for use as the Kafka Broker list. This should not be changed.

- stream
	- `kafka_bin` - This specifies the path to the Kafka bin directory. If this is different on your system, it should be set here.
	- `kafka_partitions` - This specifies the number of partitions that Kafka topics will be created with. If a differnt value is desired, set it here.
	- `kafka_replication_factor` - This specifies the replication-factor value for Kafka topics that will be created. If a different value is desired, set it here.