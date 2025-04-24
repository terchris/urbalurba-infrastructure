# raspberry readme

Notes on how to set up a Raspberry Pi with Tailscale and Kubernetes.

## Automatic setup

TODO: describe automatic setup

## Manual setup

Here we assume that you have set up the raspberry and it is connected to tailscale.
We also assume that you have the user named ansible set up on the raspberry.

Step 1: Provide the information needed to set up the raspberry in the ansible inventory.

In order to set up using ansible you need to add the raspberry to the ansible inventory. 
The information we need is stored in the file raspberry-microk8s.sh in the raspberry-microk8s folder.
This file should be created by the automatic setup, but we do it manually here.

```bash
cat << EOF > raspberry-microk8s.sh
#!/bin/bash
filename: raspberry-microk8s.sh
description: manually created created info about the raspberry
TAILSCALE_IP=100.104.212.52
CLUSTER_NAME=raspberry-microk8s
HOST_NAME=raspberry-microk8s
EOF

chmod +x raspberry-microk8s.sh
```

Step 2: Add the raspberry to the ansible inventory.

```bash
./02-raspberry-ansible-inventory.sh 
```



