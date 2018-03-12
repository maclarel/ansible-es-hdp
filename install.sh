#!/bin/bash

# To enable debug level output, uncomment the variable below.
# This can be set to -v, -vv, or -vvv depending on level of 
# output desired.
#DEBUG="-vv"

# Install Ansible if we are on Linux and
# it is not already installed.
if [ -e /etc/redhat-release ]
	then
		if [[ ! `rpm -qa |grep ansible` =~ "ansible" ]] 
			then 
				sudo yum install -y ansible
		fi
fi

# Run sshSetup.yml silently to ensure SSH access is available
# from the Ansible host to all remote machines
echo "Confirming SSH access to all servers. You may be prompted for passwords."
if ! out=`ansible-playbook playbooks/sshSetup.yml -i config`; then echo $out; fi

# Functions for each step of the installation
# Lines starting with "if ! out" can be used for a silent run
# if desired, but are disabled during development

repoInstall() {
	echo "Seting up repositories on all hosts..."
	#if ! out=`ansible-playbook playbooks/repos.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/repos.yml -i config $DEBUG
}

baselineInstall() {
	# Set baseline configuration on all config
	echo "Applying baseline to all registered hosts..."
	#if ! out=`ansible-playbook playbooks/baseline.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/baseline.yml -i config $DEBUG
}

ambariInstall() {
	# Install Ambari on ambari node
	echo "Installing Ambari Server..."
	#if ! out=`ansible-playbook playbooks/ambariserver.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/ambariserver.yml -i config $DEBUG
	echo "Installing Ambari Agent..."
	ansible-playbook playbooks/ambariagent.yml -i config $DEBUG
}

ambariConfig() {
	# Apply Ambari Service Configurations
	echo "Applying Ambari Service Configurations and restarting the cluster..."
	#if ! out=`ansible-playbook playbooks/ambariconfig.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/ambariconfig.yml -i config $DEBUG
}

ambariAgent() {
	# Apply Ambari Service Configurations
	echo "Installing Ambari Agents..."
	#if ! out=`ansible-playbook playbooks/ambariagent.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/ambariagent.yml -i config $DEBUG
}

esInstall() {
	# Install Elasticsearch
	echo "Installing Elasticsearch..."
	#if ! out=`ansible-playbook playbooks/elasticsearch.yml -i config`; then echo $out; fi
	ansible-playbook playbooks/elasticsearch.yml -i config $DEBUG
} 


while true; do

echo
echo "1 for Full Installation"
echo "2 for Repository Creation"
echo "3 for Baseline Configuration"
echo "4 for Ambari node installation"
echo "5 for Ambari managed service(s) configuration"
echo "6 for Elasticsearch node(s) installation"
echo "r to resume from a specific task name"
echo "q to exit the installer"
echo
read -p "Please select an installation option from the list above: " install_choice

case $install_choice in
	1) # Full Installation
		ansible-playbook playbooks/full_install.yml -i config $DEBUG
		;;

	2) # Repository Only
		repoInstall
		;;

	3) # Baseline Only
		baselineInstall
		;;

	4) # Ambari Only
		ambariInstall
		;;

	5) # Ambari Service Config
		ambariConfig
		;;

	6) # Search Only
		esInstall
		;;

	r) # Resume from a specific task by utilizing -start-at-task
		read -p "Please enter the task name you wish to resume from: " resume_task_name
		resumeCMD="ansible-playbook playbooks/full_install.yml -i config $DEBUG --start-at-task \""$resume_task_name"\""
		eval $resumeCMD
		echo
		;;

	q) # Quit
		echo "Exiting the installer."
		exit 0
		;;

	*) echo "Please make a valid selection"
		;;

	esac

done

# Exit successfully
exit 0
