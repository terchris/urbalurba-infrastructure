#!/bin/bash
# filename: copy2provisionhost.sh
# description: while developing we need to copy files from the local machine to the provision-host container

# copy the ansible folder to the provision-host container
docker cp ansible/. provision-host:/mnt/urbalurbadisk/ansible

if [ $? -ne 0 ]; then
    echo "Error copying ansible folder to provision-host container"
    exit 1
fi

# copy ansible playbooks folder to the provision-host container
docker cp ansible/playbooks/. provision-host:/mnt/urbalurbadisk/ansible/playbooks
if [ $? -ne 0 ]; then
    echo "Error copying ansible playbooks folder to provision-host container"
    exit 1
fi

# copy manifests folder to the provision-host container
docker cp manifests/. provision-host:/mnt/urbalurbadisk/manifests
if [ $? -ne 0 ]; then
    echo "Error copying manifests folder to provision-host container"
    exit 1
fi

# copy provision-host/kubernetes folder to the provision-host container
docker cp provision-host/. provision-host:/mnt/urbalurbadisk/provision-host
if [ $? -ne 0 ]; then
    echo "Error copying provision-host/kubernetes folder to provision-host container"
    exit 1
fi

# write sucess message
echo "Successfully copied files to provision-host container"
# exit with success
exit 0
