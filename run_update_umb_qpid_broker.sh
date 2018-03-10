#!/bin/bash
# The script will:
# 1. check git or install one
# 2. git clone the umb_qpid_ci repo
# 3. scp it to the et server which you would like to update the umb&qpid settings
# 4. log in that server, and uncompress that script then run it to finish the update

# check git or intall  one
if [[ $(git --version) =~ "git version" ]]
then
	echo "=====Git has been installed======";
else 
	echo "=====Gig has not been installed, Would intall git======"
	if [[ $(whoami) != "root" ]]
	then
		sudo su
		yum install git -y
		exit
	else
		yum install git -y
	fi
fi

# get the target file.zip
tmp_dir=$(date +'%s')
mkdir -p /tmp/${tmp_dir}
wget http://github.com/testcara/umb_qpid_ci/archive/master.zip -O ${tmp_dir}.zip

# scp the files to target the server
scp ${tmp_dir}.zip root@${1}:/tmp

# log in the server and umcompress it and then update the server
echo "=====Uncompress the target files on the target server and run the script====="
ssh -tt root@${1} << EOF
remote_tmp_dir=$(date +'%s')
mkdir -p /tmp/${remote_tmp_dir}
mv /tmp/${tmp_dir}.zip /tmp/${remote_tmp_dir}
cd /tmp/${remote_tmp_dir}
unzip ${tmp_dir}.zip
echo "=====updating umb and qpid====="
./update_umb_qpid.sh -q $2 -u $3
exit
exit
EOF
