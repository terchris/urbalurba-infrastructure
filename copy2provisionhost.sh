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

# copy hosts folder to the provision-host container
docker cp hosts/. provision-host:/mnt/urbalurbadisk/hosts
if [ $? -ne 0 ]; then
    echo "Error copying hosts folder to provision-host container"
    exit 1
fi

# copy networking folder to the provision-host container
docker cp networking/. provision-host:/mnt/urbalurbadisk/networking
if [ $? -ne 0 ]; then
    echo "Error copying networking folder to provision-host container"
    exit 1
fi

# backup existing kubernetes-secrets.yml file inside provision-host container
echo "Creating backup of existing kubernetes-secrets.yml file..."
if docker exec provision-host test -f /mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml 2>/dev/null; then
  # Create backup inside the container using sudo to avoid permission issues
  BACKUP_RESULT=$(docker exec provision-host bash -c "
    BACKUP_FILE=\"/mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml.backup.\$(date +%Y%m%d_%H%M%S)\"
    if sudo cp /mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml \"\$BACKUP_FILE\" 2>/dev/null; then
      sudo chown \$(whoami):\$(whoami) \"\$BACKUP_FILE\" 2>/dev/null || true
      echo 'Backup created successfully inside container'
    else
      echo 'Backup failed - permission denied even with sudo'
    fi
  ")
  echo "$BACKUP_RESULT"
else
  echo "No existing file to backup"
fi

# copy topsecret folder to the provision-host container
docker cp topsecret/. provision-host:/mnt/urbalurbadisk/topsecret
if [ $? -ne 0 ]; then
    echo "Error copying topsecret folder to provision-host container"
    exit 1
fi

# Fix ownership of copied files to match container user (ansible)
echo "Fixing file ownership in container..."
docker exec -u root provision-host chown -R ansible:ansible /mnt/urbalurbadisk

# write sucess message
echo "Successfully copied files to provision-host container"
# exit with success
exit 0
