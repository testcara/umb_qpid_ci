#!/bin/bash

##  Common functions for update ET umb & qpid configration
declare -a umb_original_servers
qpid_server=""
umb_server=""
umb_config_file='/var/www/errata_rails/config/initializers/credentials/message_bus.rb'
umb_handler_file='/var/www/errata_rails/lib/message_bus/handler.rb'
umb_testing_config_file='/var/www/errata_rails/examples/ruby/message_bus/umb_configuration.rb'
umb_testing_handler_file='/var/www/errata_rails/examples/ruby/message_bus/handler.rb'
qpid_config_file='/var/www/errata_rails/config/initializers/credentials/qpid.rb'
qpid_handler_file='/var/www/errata_rails/lib/message_bus/qpid_handler.rb'
umb_original_servers[0]='messaging-devops-broker01.web.stage.ext.phx2.redhat.com:5671'
umb_original_servers[1]='messaging-devops-broker01.qe.stage.ext.phx2.redhat.com:5671'
umb_original_servers[2]='messaging-devops-broker01.web.qa.ext.phx1.redhat.com:5671'
qpid_original_server='qpid.test.engineering.redhat.com'

functions_usage() {
	echo "Usage:"
	echo "'./update_umb_qpid.sh -p qpid_server -u umb_server to update all related settings'"
	echo "'./update_umb_qpid.sh -p qpid_server to update the qpid related settings'"
	echo "'./update_umb_qpid.sh -p umb_server to update the umb related settings'"
	echo "'./update_umb_qpid.sh -r to restore all umb&qpid related settings'"
}

update_service_name() {
	echo "==================Update the server hostname to ip====================="
	echo sed -i "s/ErrataSystem::SERVICE_NAME/\"0.0.0.0\"/g" ${umb_handler_file}
	sed -i "s/ErrataSystem::SERVICE_NAME/\"0.0.0.0\"/g" ${umb_handler_file}
	echo "=================Update the service hostname to ip: Done================="
}

check_return_code() {
	if [[ $? != 0 ]]; then
		exit 1
	else
		echo "=========PASS======="
	fi
}

backup_file() {
  # We will backup the origin setting of umb in which file the umb&qpid servers are stage qe servers
  # For our testing server does not use hostname, then check the ip.
  # If the file contains one ip, then we would not backup. Otherwise we do.
  if [[ $(grep '10.' $1 | wc -l) -lt 0 ]]; then
  	echo "==[Info]The current setting is not original file, we would not backup it=="
  elif [[ -e "${1}_stage_qe_broker_backup" ]]; then
  	echo "===[Info]The backup file has been existing. we would not backup it again==="
  else
  	echo "===[Info]Backuping the file===="
  	cp "${1}" "${1}_stage_qe_broker_backup"
  fi
}

restore_file() {
	if [[ -e "${1}_stage_qe_broker_backup" ]]; then
		echo "===Would restore the file ${1} back===="
		cp -r "${1}_stage_qe_broker_backup" "${1}"
		chown -R erratatool:errata "${1}"
	fi
}

remove_redundant_end() {
	for message in "Using cert #{@cert} & key #{@key}" "messenger.private_key = @key"
	do
		previous_line_number=$(grep -n "${message}" ${1} | cut -d ":" -f 1)
		end_line_number=$((${previous_line_number}+1))
		sed -i "${end_line_number}s/^/#/" ${1}
	done
}

restore_servers() {
	for server_file in ${umb_config_file} ${umb_handler_file} ${umb_testing_config_file} ${umb_testing_handler_file} \
	${qpid_config_file}  ${qpid_handler_file}
	do
		restore_file ${server_file}
	done
    restart_service
}

restart_service() {
	echo "==============Restart the service======================"
	/etc/init.d/httpd24-httpd restart
	check_return_code
	/etc/init.d/delayed_job restart
	check_return_code
	/etc/init.d/qpid_service restart
	check_return_code
	/etc/init.d/messaging_service restart
	check_return_code
	echo "==============Restart the service: Done================="
}

update_qpid_setting() {
	for qpid_files in ${qpid_config_file}  ${qpid_handler_file}
	do
		backup_file ${qpid_files}
	done
	echo "=====Update the ${qpid_config_file} setting======"
	sed -i "s/qpid.test.engineering.redhat.com/${qpid_server}/g" ${qpid_config_file}
	sed -i "s/5671/5672/g"  ${qpid_config_file}
	echo "=====Update the ${qpid_config_file} setting: Done======"
	echo "=====Update the qpid handler authentication mode====="
	sed -i "s/GSSAPI/ANONYMOUS/g" ${qpid_handler_file}
	echo "=====Update the qpid handler authentication mode: Done====="
	update_service_name ${qpid_handler_file}

}

update_umb_setting() {
	for umb_files in ${umb_config_file} ${umb_handler_file} ${umb_testing_config_file} ${umb_testing_handler_file}
	do
		backup_file ${umb_files}
	done
	echo "=====Update the umb server ip setting======"
	for umb_original_server in umb_original_servers
	do
		sed -i "s/${umb_original_server}/${umb_server}/g"  ${umb_config_file}
		sed -i "s/amqps/amqp/g"  ${umb_config_file}
		sed -i "s/${umb_original_server}/${umb_server}/g"  ${umb_testing_config_file}
		sed -i "s/amqps/amqp/g"  ${umb_testing_config_file}
	done
	echo "=====Disable the CA parts of the umb server setting====="
	for cert_file in 'CLIENT_CERT' 'CLIENT_KEY' 'CERT_NAME'
	do
		sed -i "/${cert_file}/s/^/#/"  ${umb_config_file}
		sed -i "/${cert_file}/s/^/#/"  ${umb_testing_config_file}
	done
	echo "=====Disable the CA parts of the umb handler setting====="
	for cert_file in '@cert' '@key'
	do
		sed -i "/${cert_file}/s/^/#/"  ${umb_handler_file}
		sed -i "/${cert_file}/s/^/#/"  ${umb_testing_handler_file}
	done
	echo "=====Disable the redundant 'end' and change hostname to server ip====="
	for handler_file in ${umb_handler_file} ${umb_testing_handler_file}
	do
		remove_redundant_end ${handler_file}
		update_service_name ${handler_file}
	done
	echo "=====Add sleep to the process of sending message====="
	sed -i "/msg.body = content/a \      sleep 5"  ${umb_handler_file}
}

while getopts "q:u:hr" opt; do  
  case $opt in  
    p)
		echo "======Found parameter q: qpid server is $OPTARG========="
		qpid_server=$OPTARG
		;;  
    u)
		echo "======Found parameter u: umb server is $OPTARG=========="
		umb_server=OPTARG
		;;  
    r)
		echo "======Found parameter r: would ignore the -p and -u setting============"
		echo "======Would restore the umb&qpid setting to the original ones=========="
		restore_servers
		check_return_code
		echo "======restore the umb&qpid setting to the original ones: Done=========="
		;;
	h)
		functions_usage
		;;
    \?)  
      echo "Invalid option: -$OPTARG"   
      ;;  
  esac  
done  
if [[ -n ${qpid_server} ]] ; then
	echo "=====Would update qpid related settings========"
	update_qpid_setting
	check_return_code
	echo "=====Update qpid related settings: Done========"
	restart_service
fi

if [[ -n ${umb_server} ]] ; then
	echo "=====Would update umb related settings========"
	update_umb_setting
	check_return_code
	echo "=====Update umb related settings: Done========"
	restart_service
fi








