#!/bin/bash

LOC_AMBARI_SCRIPT_PATH=/var/lib/ambari-server/resources/scripts
LOC_AMBARI_USER_NAME=$1
LOC_AMBARI_USER_PASSWORD=$2
LOC_AMBARI=$3
LOC_AMBARI_CLUSTER_NAME=$4
LOC_SET_CONFIG=$5
loc_ambari_cmd='$LOC_AMBARI_SCRIPT_PATH/configs.sh -u $LOC_AMBARI_USER_NAME -p $LOC_AMBARI_USER_PASSWORD set $LOC_AMBARI $LOC_AMBARI_CLUSTER_NAME <line>'
loc_bool_property_content=0
loc_counter=0
loc_ambari_service_property=""
loc_ambari_content=""
loc_ambari_config=""
loc_uid=$(date +%s)


	while read -r line; do
		loc_ambari_cmd='$LOC_AMBARI_SCRIPT_PATH/configs.sh -u $LOC_AMBARI_USER_NAME -p $LOC_AMBARI_USER_PASSWORD set $LOC_AMBARI $LOC_AMBARI_CLUSTER_NAME <line>'

				#If property is content we need to put all content into one line
				if [  $loc_bool_property_content -eq 1 ]; then
						if [[ "$line" = '{' ]] ; then
								continue
						fi

						# Can't find corresponding } .. This means the content value is malformed
						if [ $loc_counter -gt 1000 ] || [[ $line =~ '#---' ]] ; then
								echo "ERROR IN etc/ambari_config content malformed. Missing corresponding } : $loc_ambari_service_property"
								exit
						fi

						# End of Ambari content need to wrap everything up by escaping quotes slashes and making it one line
						if [[ "$line" = '}' ]] ; then
							loc_ambari_cmd='$LOC_AMBARI_SCRIPT_PATH/configs.sh -u $LOC_AMBARI_USER_NAME -p $LOC_AMBARI_USER_PASSWORD set $LOC_AMBARI $LOC_AMBARI_CLUSTER_NAME <line> "$loc_ambari_content"'

							loc_bool_property_content=0
							echo "$loc_ambari_content" >./temp"$loc_uid".txt

							#trying to escape special string characters
							sed -i 's,/,\\/,g' temp"$loc_uid".txt
							sed -i 's/"/\\"/g' temp"$loc_uid".txt
							loc_ambari_content=$(cat temp"$loc_uid".txt)

							loc_ambari_cmd=$(echo $loc_ambari_cmd | sed -e 's/<line>/'"$loc_ambari_service_property"'/')
							eval $loc_ambari_cmd
							else
							#Concatenating Ambari Content Value

							line=$(echo "${line}" | sed -e 's/^[[:space:]]*//')

							if [ "$loc_ambari_content" == "" ] ; then
								loc_ambari_content=$line
							else
								loc_ambari_content=$loc_ambari_content"\\n"$line
							fi
							loc_counter=$((loc_counter+1))
						fi

						continue
				fi

		# Section Break skip
		if [[ $line =~ '#---' ]] ; then
			continue
		fi
		if [[ $line = ' ' ]] ; then
			continue
		fi

		#STRIP LEADING WHTIESPACE
		line=$(echo "${line}" | sed -e 's/^[[:space:]]*//')

		loc_property=$(echo $line | cut -f2 -d' ')
		echo "--UPDATING: $line"

		#PROPERTY CONTENT FLAG IT SO WE CAN PROCESS DATA
		# LIKE ESCAPE SPECIAL CHARACTERS AND TURN MULTILINE INTO
		# ONE LINE
		if [ $loc_property = 'content' ]; then
			loc_ambari_service_property=$line
			loc_ambari_content=""
			loc_counter=0
			loc_bool_property_content=1
			continue

		fi

		echo "$line" >./temp"$loc_uid".txt
		sed -i 's,/,\\/,g' temp"$loc_uid".txt
		line=$(cat temp"$loc_uid".txt)
		loc_ambari_cmd=$(echo $loc_ambari_cmd | sed -e 's/<line>/'"$line"'/')
		eval $loc_ambari_cmd

	done < /tmp/ambari_config
	rm -f temp"$loc_uid".txt 