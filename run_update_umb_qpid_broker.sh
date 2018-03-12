#!/bin/bash
# The script will:
# 1. check the wget installed and get the scripts
# 2. scp it to the et server which you would like to update the umb&qpid settings
# 3. log in that server, and uncompress that script then run it to finish the update

# prepare the env, install git and wget
if [[ $(wget --version | head -1) =~ "GNU Wget" ]]
then
	echo "=====wget has been installed======";
else
	echo "=====wget has not been installed, Would intall git======"
	sudo yum install wget -y
fi

# get the target file.zip
tmp_dir=$(date +'%s')
mkdir -p /tmp/${tmp_dir}
wget http://github.com/testcara/umb_qpid_ci/archive/master.zip -O ${tmp_dir}.zip

# scp the files to target the server
ssh root@${et_ip} "mkdir -p /tmp/${tmp_dir}"
scp ${tmp_dir}.zip root@${et_ip}:/tmp/${tmp_dir}

# log in the server and umcompress it and then update the server
echo "=====Uncompress the target files on the target server and run the script====="
ssh -tt root@${et_ip} << EOF
cd /tmp/${tmp_dir}
unzip ${tmp_dir}.zip
echo "=====updating umb and qpid====="
cd /tmp/${tmp_dir}/umb_qpid_ci-master/
./update_umb_qpid.sh -q ${qpid_broker} -u ${umb_broker}
if [[ $? == 0 ]]; then
  echo "======Done======"
else
  echo "======FAILED====="
  exit 1
fi
exit
exit
EOF

#delete the useless file
ssh root@${et_ip} "rm -r /tmp/${tmp_dir}"
rm -r /tmp/${tmp_dir}