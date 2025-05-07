#!/bin/bash
# file: scripts/manage/k9s.sh

# Script to that starts k9s to display what is going on in the cluster.
# the script is to be run on your host computer. It connects to the provision-host and starts the k9s command.
# starts k9s so that it lists pods in the all namespaces.  

echo "Starting k9s..."
echo "IMPORTANT: When you are done, you can stop k9s by pressing Esc first and then ':' followed by 'q' and then Enter."
read -r -p "Press Enter to continue"
docker exec -it provision-host bash -c "k9s --namespace all"
