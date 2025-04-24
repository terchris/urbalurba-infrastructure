# Provision Host for Rancher Desktop

This directory contains scripts to create a Docker container that serves as a provisioning host for Kubernetes environments using Rancher Desktop.

## Overview

The provision host container provides a consistent environment with all the necessary tools for managing Kubernetes clusters. It's designed to work seamlessly with Rancher Desktop, providing:

1. A complete set of cloud provider tools
2. Kubernetes management utilities
3. Networking tools
4. Helm and repository configuration

## What This System Does

The provision host container setup:

1. **Creates a Docker container** with all necessary tools for Kubernetes management
2. **Provisions the container** with essential software:
   - Core software (Git, Python, etc.)
   - Cloud provider tools (Azure CLI, AWS CLI, etc.)
   - Kubernetes tools (kubectl, Helm, etc.)
   - Networking tools (Cloudflared)
   - Helm repositories
3. **Sets up Kubernetes context** for Rancher Desktop:
   - Creates a "default" context alias pointing to the Rancher Desktop cluster
   - Verifies storage class configuration
   - Applies necessary Kubernetes secrets

## Microk8s Compatibility

This setup is designed to be compatible with scripts originally written for Microk8s:

1. **Context Naming**: 
   - Default context in Microk8s is named `default`
   - We create a `default` context in Rancher Desktop that points to the same cluster as `rancher-desktop`
   - This allows scripts that expect the `default` context to work without modification

2. **Storage Class Compatibility**:
   - Microk8s uses `microk8s-hostpath` as its storage class
   - We create a `microk8s-hostpath` storage class alias in Rancher Desktop that points to `local-path`
   - This ensures that PVCs and deployments expecting the Microk8s storage class work seamlessly

This compatibility layer allows you to run the same Kubernetes scripts and manifests on both Microk8s and Rancher Desktop environments without modification.

## Understanding the Logs

When running the installation scripts, you'll see detailed logs of the process. Here's how to interpret them:

### Container Creation and Provisioning

```
==========------------------> Step 1: Create provision-host container
```

### Kubernetes Environment Setup

```
==========------------------> Step 2: Setup Kubernetes environment (using Rancher Desktop)
```

This section shows the Kubernetes configuration. Look for:
- Secret application status
- Context configuration
- Storage class verification

A successful Kubernetes setup will include:

```
Creating 'default' context alias for rancher-desktop...
'default' context is correctly set up
```

This indicates that a "default" context has been created that points to your Rancher Desktop cluster, allowing scripts that expect a "default" context to work correctly.

When you see this output, it means the system has successfully:

1. Created a `default` context that points to the same cluster as the `rancher-desktop` context
2. This ensures compatibility with scripts that were written for Microk8s, which uses `default` as its context name

Similarly, when you see:

```
storageclass.storage.k8s.io/microk8s-hostpath created
```

This indicates that a storage class alias has been created to maintain compatibility with Microk8s storage:

1. The `microk8s-hostpath` storage class is created as an alias to Rancher Desktop's `local-path` storage
2. This allows PVCs and deployments that were configured for Microk8s to work without modification

### Storage Class Verification

### Context Issues

If you see errors about contexts:
- Check if the rancher-desktop context exists: `kubectl config get-contexts`
- Manually create the default context if needed:
  ```
  kubectl config set-context default --cluster=rancher-desktop --user=rancher-desktop
  ```

### Storage Class Issues

If you encounter storage-related errors:
- Verify the storage class alias exists: `kubectl get storageclass microk8s-hostpath`
- If missing, create it manually:
  ```
  kubectl apply -f /mnt/urbalurbadisk/manifests/000-storage-class-alias.yaml
  ```
- Test storage with a simple PVC: `kubectl apply -f /mnt/urbalurbadisk/manifests/001-storage-class-test-pvc.yaml`


## Install summary

```plaintext
---------- Provisioning Summary: /mnt/urbalurbadisk/provision-host/provision-host-provision.sh ----------
provision-host-00-coresw.sh: Success
provision-host-01-cloudproviders.sh: Success
provision-host-02-kubetools.sh: Success
provision-host-03-net.sh: Success
provision-host-04-helmrepo.sh: Success
All provisioning scripts completed successfully.
Verifying setup...
Testing container access...
ansible
Container access test successful.
---------- Setup Summary ----------
Prerequisites: OK
Container creation: OK
Transferring ansible directory: OK
Transferring manifests folder: OK
Transferring hosts folder: OK
Transferring cloud-init folder: OK
Transferring networking folder: OK
Transferring provision-host folder: OK
Transferring provision-host-rancher folder: OK
Additional files copy: OK
Provisioning: OK
Container test: OK

Setup completed successfully!

You can now:
1. Access the container with:
   docker exec -it provision-host bash
2. Run commands directly with:
   docker exec provision-host <command>
provision-host-container-create.sh in provision-host-rancher completed successfully.
==========------------------> Step 2: Setup Kubernetes environment (using Rancher Desktop)
- Script:./install-rancher.sh -----------------> Running install-rancher-kubernetes.sh  in directory: hosts
==========------------------> Step 1: Create VM - SKIPPED (using Rancher Desktop)
==========------------------> Step 2: Register VM in ansible inventory - SKIPPED (using Rancher Desktop)
==========------------------> Step 3: Install software on VM - SKIPPED (using Rancher Desktop)
==========------------------> Step 4: Applying secrets to the Rancher Desktop cluster
- Script: ./install-rancher-kubernetes.sh -----------------> Running update-kubernetes-secrets-rancher.sh  in directory: ../topsecret
No context provided. Using default context: rancher-desktop
Starting the process to update Kubernetes secrets to cluster: rancher-desktop...
1: Checking if the Kubernetes secrets file exists
2: Checking if container is running...
3: Checking if the context rancher-desktop exists in the container...
4: Checking if the namespace default exists in the context rancher-desktop...
default
5: Applying secrets to Kubernetes cluster for context rancher-desktop...
secret/urbalurba-secrets created
secret/ghcr-credentials created
secret/cloudflared-credentials created
secret/pgadmin4-password created
6: Verifying secrets were created in namespace default for context rancher-desktop...
NAME                      TYPE                             DATA   AGE
cloudflared-credentials   Opaque                           2      0s
ghcr-credentials          kubernetes.io/dockerconfigjson   1      0s
pgadmin4-password         Opaque                           1      0s
urbalurba-secrets         Opaque                           54     0s
------ Summary of test statuses ------
Kubernetes secrets file existence: OK
Container running: OK
Context check: OK
Namespace check/creation: OK
Apply secrets: OK
Verify secrets: OK
--------------- All OK ------------------------
Kubernetes secrets have been successfully updated.
==========------------------> Step 4.1: Setting up Kubernetes environment
- Script: ./install-rancher-kubernetes.sh -----------------> Running 01-setup-kubernetes-rancher.sh  in directory: rancher-kubernetes
Setting up Kubernetes environment for Rancher Desktop...
Setting kubectl context to rancher-desktop...
Switched to context "rancher-desktop".
Creating 'default' context alias for rancher-desktop...
Context "default" modified.
Created 'default' context pointing to rancher-desktop cluster
Verifying 'default' context...
'default' context is correctly set up
Kubernetes environment setup completed successfully.
==========------------------> Step 4.2: Verifying storage class setup
Running storage class verification inside the provision-host container...
storageclass.storage.k8s.io/microk8s-hostpath created
Step 1: Creating storage class alias...
Step 1b: Verifying storage class creation...
Storage class created and verified successfully
Step 2: Creating test PVC...
persistentvolumeclaim/storage-test-pvc created
Step 3: Creating test pod...
pod/storage-test-pod created
Step 4: Waiting for pod to be ready...
pod/storage-test-pod condition met
Step 5: Verifying file creation...
Storage test successful
Storage test passed successfully!
Step 6: Cleaning up...
pod "storage-test-pod" deleted
persistentvolumeclaim "storage-test-pvc" deleted
Storage class verification completed successfully!
==========------------------> Step 5: Install local kubeconfig - SKIPPED (using Rancher Desktop config)
------ Summary of installation statuses for: ./install-rancher-kubernetes.sh ------
Step 1 - Create VM: Skipped (using Rancher Desktop)
Step 2 - Register VM: Skipped (using Rancher Desktop)
Step 3 - Install software: Skipped (using Rancher Desktop)
update-kubernetes-secrets-rancher.sh in ../topsecret: OK
01-setup-kubernetes-rancher.sh in rancher-kubernetes: OK
Storage class verification: OK
Step 5 - Install kubeconfig: Skipped (using Rancher Desktop config)
--------------- All OK ------------------------
Kubernetes secrets have been successfully applied to Rancher Desktop.
install-rancher-kubernetes.sh in hosts completed successfully.
==========------------------> Step 3: Install local kubeconfig - SKIPPED (using Rancher Desktop config)
----------------------> Start the installation of kubernetes systems <----------------------
Preparing Rancher Desktop environment...
Setting up Rancher Desktop environment...
Copying Rancher Desktop kubeconfig...
Setting up Ansible inventory for Rancher Desktop...
Running kubeconfig merge playbook...

PLAY [Merge Kubeconfig Files and Set Permissions] ******************************

TASK [Gathering Facts] *********************************************************
ok: [localhost]

TASK [1. Playbook running as user] *********************************************
ok: [localhost] => {
    "msg": "Playbook running as user: ansible, Ansible connecting as: ansible"
}

TASK [2. Check if kubectl is available] ****************************************
ok: [localhost]

TASK [3. Check if kubernetes_files_path exists] ********************************
ok: [localhost]

TASK [4. Fail if kubernetes_files_path does not exist] *************************
skipping: [localhost]

TASK [5. Find all kubeconfig files] ********************************************
ok: [localhost]

TASK [6. Ensure temporary directory is clean and exists] ***********************
ok: [localhost] => (item=absent)
changed: [localhost] => (item=directory)

TASK [7. Copy kubeconfig files to temporary directory] *************************
changed: [localhost] => (item={'path': '/mnt/urbalurbadisk/kubeconfig/rancher-desktop-kubeconf', 'mode': '0600', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 1000, 'gid': 1000, 'size': 8735, 'inode': 4063252, 'dev': 41, 'nlink': 1, 'atime': 1741019440.3100004, 'mtime': 1741019440.3100004, 'ctime': 1741019440.3100004, 'gr_name': 'ansible', 'pw_name': 'ansible', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': False, 'xgrp': False, 'woth': False, 'roth': False, 'xoth': False, 'isuid': False, 'isgid': False})

TASK [8. Find all kubeconfig files in temp directory] **************************
ok: [localhost]

TASK [9. Get file stats for sorting] *******************************************
ok: [localhost] => (item={'path': '/mnt/urbalurbadisk/kubeconfig/tmp/rancher-desktop-kubeconf', 'mode': '0600', 'isdir': False, 'ischr': False, 'isblk': False, 'isreg': True, 'isfifo': False, 'islnk': False, 'issock': False, 'uid': 1000, 'gid': 1000, 'size': 8735, 'inode': 4063332, 'dev': 41, 'nlink': 1, 'atime': 1741019443.0400002, 'mtime': 1741019442.9300003, 'ctime': 1741019443.0400002, 'gr_name': 'ansible', 'pw_name': 'ansible', 'wusr': True, 'rusr': True, 'xusr': False, 'wgrp': False, 'rgrp': False, 'xgrp': False, 'woth': False, 'roth': False, 'xoth': False, 'isuid': False, 'isgid': False})

TASK [10. Sort kubeconfig files by modification time] **************************
ok: [localhost]

TASK [11. Get the most recent kubeconfig file] *********************************
ok: [localhost]

TASK [12. Display the most recent kubeconfig file] *****************************
ok: [localhost] => {
    "most_recent_kubeconfig.stat.path": "/mnt/urbalurbadisk/kubeconfig/tmp/rancher-desktop-kubeconf"
}

TASK [13. Apply update patterns to kubeconfig files] ***************************
ok: [localhost] => (item=Updating rancher-desktop-kubeconf with pattern name: microk8s-cluster\b)
ok: [localhost] => (item=Updating rancher-desktop-kubeconf with pattern cluster: microk8s-cluster\b)
changed: [localhost] => (item=Updating rancher-desktop-kubeconf with pattern user: admin\b)
ok: [localhost] => (item=Updating rancher-desktop-kubeconf with pattern name: microk8s\b)
changed: [localhost] => (item=Updating rancher-desktop-kubeconf with pattern - name: admin\b)

TASK [14. Merge all modified kubeconfig files] *********************************
changed: [localhost]

TASK [15. Clean up temporary directory] ****************************************
changed: [localhost]

TASK [16. Display file permissions] ********************************************
ok: [localhost]

TASK [17. Show file permissions] ***********************************************
ok: [localhost] => {
    "msg": "File /mnt/urbalurbadisk/kubeconfig/kubeconf-all permissions: mode: 0644, owner: ansible, group: ansible\n"
}

TASK [18. Get the base name of the most recent kubeconfig file] ****************
ok: [localhost]

TASK [19. Set the current context based on the most recent kubeconfig file] ****
changed: [localhost]

TASK [20. Verify the current context in the merged file] ***********************
ok: [localhost]

TASK [21. Display the current context to verify] *******************************
ok: [localhost] => {
    "current_context_output.stdout": "rancher-desktop"
}

TASK [22. Fail if the context is not set correctly] ****************************
skipping: [localhost]

TASK [23. Add KUBECONFIG environment variable to system-wide profile] **********
changed: [localhost]

TASK [24. Add KUBECONFIG to /etc/environment] **********************************
changed: [localhost]

TASK [25. List and display all contexts in the merged kubeconfig] **************
ok: [localhost]

TASK [26. Display all contexts] ************************************************
ok: [localhost] => {
    "contexts_output.stdout_lines": [
        "CURRENT   NAME                 CLUSTER                      AUTHINFO                                   NAMESPACE",
        "          default              rancher-desktop              rancher-desktop                            ",
        "          multipass-microk8s   multipass-microk8s-cluster   admin-rancher-desktop-multipass-microk8s   ",
        "*         rancher-desktop      rancher-desktop              rancher-desktop                            "
    ]
}

TASK [27. List all pods in the current context] ********************************
ok: [localhost]

TASK [28. Display the list of pods] ********************************************
ok: [localhost] => {
    "pods_output.stdout_lines": [
        "NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE",
        "kube-system   coredns-ccb96694c-fx7ds                   1/1     Running     0          9m50s",
        "kube-system   helm-install-traefik-crd-4r54l            0/1     Completed   0          9m50s",
        "kube-system   helm-install-traefik-kggn8                0/1     Completed   1          9m50s",
        "kube-system   local-path-provisioner-5b5f758bcf-sl75p   1/1     Running     0          9m50s",
        "kube-system   metrics-server-7bf7d58749-h6xl4           1/1     Running     0          9m50s",
        "kube-system   svclb-traefik-ce565dc2-9whgc              2/2     Running     0          9m47s",
        "kube-system   traefik-5cbdcf97f4-tffvr                  1/1     Running     0          9m47s"
    ]
}

RUNNING HANDLER [Inform user to reload system-wide environment] ****************
ok: [localhost] => {
    "msg": "KUBECONFIG environment variable has been added system-wide. Please reload your shell or log out and log back in for the changes to take effect.\n"
}

PLAY RECAP *********************************************************************
localhost                  : ok=28   changed=8    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   

Environment setup complete.
Testing Kubernetes configuration...
NAME                   STATUS   ROLES                  AGE     VERSION
lima-rancher-desktop   Ready    control-plane,master   9m54s   v1.31.6+k3s1
Kubernetes configuration test successful!
Testing Ansible inventory...
[WARNING]: Invalid characters were found in group names but not replaced, use
-vvvv to see details
[WARNING]: Platform linux on host localhost is using the discovered Python
interpreter at /usr/bin/python3.10, but future installation of another Python
interpreter could change the meaning of that path. See
https://docs.ansible.com/ansible-
core/2.17/reference_appendices/interpreter_discovery.html for more information.
localhost | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3.10"
    },
    "changed": false,
    "ping": "pong"
}
Ansible inventory test successful!
Rancher Desktop environment is ready for Kubernetes provisioning.
Starting Kubernetes provisioning on lima-rancher-desktop for target-host: rancher-desktop
---------------------------------------------------
Changing to directory: /mnt/urbalurbadisk/provision-host/kubernetes
Successfully changed to correct directory: /mnt/urbalurbadisk/provision-host/kubernetes
Processing directory: ./01-default-apps
Running ./01-default-apps/05-cloud-setup-postgres.sh with target-host: rancher-desktop...
- Script: 05-cloud-setup-postgres.sh ----- Starting PostgreSQL setup on rancher-desktop -----
---------------------------------------------------
Testing connection to rancher-desktop...
[WARNING]: Could not match supplied host pattern, ignoring: rancher-desktop
[WARNING]: No hosts matched, nothing to do
Verifying Kubernetes context...
Switched to context "rancher-desktop".
05-cloud-setup-postgres.sh: Running playbook for Setup PostgreSQL: 040-database-postgresql.yml...

PLAY [Set up PostgreSQL Database] **********************************************

TASK [1. Check if target_host is provided] *************************************
skipping: [localhost]

TASK [2. Print playbook description] *******************************************
ok: [localhost] => {
    "msg": "Setting up PostgreSQL on MicroK8s on Ubuntu host: rancher-desktop with manifests from: /mnt/urbalurbadisk/manifests. Use -e target_host=your_host_name to change settings."
}

TASK [3. Verify PostgreSQL secret values] **************************************
[WARNING]: kubernetes<24.2.0 is not supported or tested. Some features may not
work.
ok: [localhost]

TASK [4. Fail if PostgreSQL secrets are not set correctly] *********************
skipping: [localhost]

TASK [5. Set PostgreSQL password] **********************************************
ok: [localhost]

TASK [6. Check if PostgreSQL is already installed] *****************************
ok: [localhost]

TASK [7. Deploy PostgreSQL using Helm if not already installed] ****************
changed: [localhost]

TASK [8. Wait for PostgreSQL pod to be running] ********************************
FAILED - RETRYING: [localhost]: 8. Wait for PostgreSQL pod to be running (20 retries left).
FAILED - RETRYING: [localhost]: 8. Wait for PostgreSQL pod to be running (19 retries left).
FAILED - RETRYING: [localhost]: 8. Wait for PostgreSQL pod to be running (18 retries left).
changed: [localhost]

TASK [9. Verify PostgreSQL service is running] *********************************
ok: [localhost]

TASK [10. Display PostgreSQL service details] **********************************
ok: [localhost] => {
    "postgres_svc.resources[0].spec": {
        "clusterIP": "10.43.127.215",
        "clusterIPs": [
            "10.43.127.215"
        ],
        "internalTrafficPolicy": "Cluster",
        "ipFamilies": [
            "IPv4"
        ],
        "ipFamilyPolicy": "SingleStack",
        "ports": [
            {
                "name": "tcp-postgresql",
                "port": 5432,
                "protocol": "TCP",
                "targetPort": "tcp-postgresql"
            }
        ],
        "selector": {
            "app.kubernetes.io/component": "primary",
            "app.kubernetes.io/instance": "postgresql",
            "app.kubernetes.io/name": "postgresql"
        },
        "sessionAffinity": "None",
        "type": "ClusterIP"
    }
}

PLAY RECAP *********************************************************************
localhost                  : ok=8    changed=2    unreachable=0    failed=0    skipped=2    rescued=0    ignored=0   

05-cloud-setup-postgres.sh: Running playbook for Verify PostgreSQL: u02-verify-postgres.yml...

PLAY [Verify PostgreSQL Database] **********************************************

TASK [1. Verify PostgreSQL secret values] **************************************
[WARNING]: kubernetes<24.2.0 is not supported or tested. Some features may not
work.
ok: [localhost]

TASK [2. Fail if PostgreSQL secrets are not set correctly] *********************
skipping: [localhost]

TASK [3. Set PostgreSQL password and host] *************************************
ok: [localhost]

TASK [4. Get PostgreSQL pod name] **********************************************
ok: [localhost]

TASK [5. Fail if no PostgreSQL pod found] **************************************
skipping: [localhost]

TASK [6. Set PostgreSQL pod name] **********************************************
ok: [localhost]

TASK [7. Wait for PostgreSQL to be ready] **************************************
changed: [localhost]

TASK [8. Create test database] *************************************************
changed: [localhost]

TASK [9. Create test table and insert data] ************************************
changed: [localhost]

TASK [10. Retrieve data from test table] ***************************************
changed: [localhost]

TASK [11. Display retrieved data] **********************************************
ok: [localhost] => {
    "retrieve_result.stdout_lines": [
        " id |    data    ",
        "----+------------",
        "  1 | test_value",
        "(1 row)"
    ]
}

TASK [12. Verify retrieved data] ***********************************************
skipping: [localhost]

TASK [13. Drop test database] **************************************************
changed: [localhost]

TASK [14. Confirm PostgreSQL is working correctly] *****************************
ok: [localhost] => {
    "msg": "PostgreSQL is working correctly. Test database created, data inserted and retrieved successfully, and test database dropped."
}

PLAY RECAP *********************************************************************
localhost                  : ok=11   changed=5    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

- Script: 05-cloud-setup-postgres.sh ----- Installation Summary ----- Target Host: rancher-desktop
Setting context to cluster: rancher-desktop: OK
Verify PostgreSQL: OK
Test connection: OK
Setup PostgreSQL: OK
All steps completed successfully.
./01-default-apps/05-cloud-setup-postgres.sh completed successfully.
---------------------------------------------------
Running ./01-default-apps/06-setup-redis.sh with target-host: rancher-desktop...
Starting Redis setup on rancher-desktop
---------------------------------------------------
Testing connection to rancher-desktop...
[WARNING]: Could not match supplied host pattern, ignoring: rancher-desktop
[WARNING]: No hosts matched, nothing to do
Running playbook for Setup Redis...

PLAY [localhost] ***************************************************************

TASK [Check if target_host is provided] ****************************************
skipping: [localhost]

TASK [Print playbook description] **********************************************
ok: [localhost] => {
    "msg": "Setting up redis on MicroK8s on Ubuntu host: rancher-desktop with manifests from: /mnt/urbalurbadisk/manifests. Use -e target_host=your_host_name to change settings."
}

TASK [Get Redis password from Kubernetes secrets] ******************************
changed: [localhost]

TASK [Set Redis password fact] *************************************************
ok: [localhost]

TASK [Debug Redis password (masked)] *******************************************
ok: [localhost] => {
    "msg": "Redis password: ***************"
}

TASK [Deploy redis using Helm] *************************************************
changed: [localhost]

TASK [Wait for redis pod to be ready] ******************************************
changed: [localhost]

TASK [Verify Redis service is running] *****************************************
changed: [localhost]

TASK [Display Redis service details] *******************************************
ok: [localhost] => {
    "redis_svc.stdout_lines": [
        "NAME             TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE",
        "kubernetes       ClusterIP   10.43.0.1       <none>        443/TCP    11m",
        "redis-headless   ClusterIP   None            <none>        6379/TCP   48s",
        "redis-master     ClusterIP   10.43.196.139   <none>        6379/TCP   48s"
    ]
}

TASK [Get Redis pod name] ******************************************************
changed: [localhost]

TASK [Display Redis pod name] **************************************************
ok: [localhost] => {
    "redis_pod_name.stdout": "redis-master-0"
}

TASK [Authenticate to Redis] ***************************************************
changed: [localhost]

TASK [Display Redis auth result] ***********************************************
ok: [localhost] => {
    "msg": "Redis authentication successful"
}

TASK [Ping Redis] **************************************************************
changed: [localhost]

TASK [Display Redis ping result] ***********************************************
ok: [localhost] => {
    "redis_ping.stdout": "PONG"
}

TASK [Check if Redis is working] ***********************************************
skipping: [localhost]

TASK [Confirm Redis is working] ************************************************
ok: [localhost] => {
    "msg": "Redis is working correctly"
}

TASK [Set a key in Redis] ******************************************************
changed: [localhost]

TASK [Display set key result] **************************************************
ok: [localhost] => {
    "set_redis_key.stdout": "OK"
}

TASK [Get the key from Redis] **************************************************
changed: [localhost]

TASK [Display get key result] **************************************************
ok: [localhost] => {
    "get_redis_key.stdout": "world"
}

TASK [Check if key set and get is working] *************************************
skipping: [localhost]

TASK [Confirm Redis set and get key is working] ********************************
ok: [localhost] => {
    "msg": "Redis set and get key is working correctly"
}

PLAY RECAP *********************************************************************
localhost                  : ok=20   changed=9    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

---------- Installation Summary ----------
Test connection: OK
Setup Redis: OK
All steps completed successfully.
./01-default-apps/06-setup-redis.sh completed successfully.
---------------------------------------------------
Running ./01-default-apps/07-setup-elasticsearch.sh with target-host: rancher-desktop...
Starting Elasticsearch setup on rancher-desktop
---------------------------------------------------
Testing connection to rancher-desktop...
[WARNING]: Could not match supplied host pattern, ignoring: rancher-desktop
[WARNING]: No hosts matched, nothing to do
Running playbook for Setup Elasticsearch...

PLAY [Set up Elasticsearch on MicroK8s] ****************************************

TASK [1. Check if required variables are provided] *****************************
skipping: [localhost]

TASK [2. Set Elasticsearch namespace] ******************************************
ok: [localhost]

TASK [3. Print playbook description] *******************************************
ok: [localhost] => {
    "msg": "Setting up Elasticsearch on MicroK8s on Ubuntu host: rancher-desktop with manifests from: /mnt/urbalurbadisk/manifests. Using namespace: elasticsearch\n"
}

TASK [4. Get Elasticsearch password from Kubernetes secrets] *******************
ok: [localhost]

TASK [5. Set Elasticsearch password fact] **************************************
ok: [localhost]

TASK [6. Debug Elasticsearch password (masked)] ********************************
ok: [localhost] => {
    "msg": "Elasticsearch password: ***************"
}

TASK [7. Deploy Elasticsearch using Helm] **************************************
changed: [localhost]

TASK [8. Wait for Elasticsearch pod to be ready] *******************************
ok: [localhost]

TASK [9. Verify Elasticsearch service is running] ******************************
ok: [localhost]

TASK [10. Display Elasticsearch service details] *******************************
ok: [localhost] => {
    "elasticsearch_svc.stdout_lines": [
        "NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE",
        "elasticsearch   ClusterIP   10.43.179.209   <none>        9200/TCP,9300/TCP   3m26s"
    ]
}

TASK [11. Get Elasticsearch pod name] ******************************************
ok: [localhost]

TASK [12. Check Elasticsearch cluster health] **********************************
ok: [localhost]

TASK [13. Display Elasticsearch health] ****************************************
ok: [localhost] => {
    "elasticsearch_health.stdout_lines": [
        "{",
        "  \"cluster_name\" : \"elasticsearch\",",
        "  \"status\" : \"green\",",
        "  \"timed_out\" : false,",
        "  \"number_of_nodes\" : 1,",
        "  \"number_of_data_nodes\" : 1,",
        "  \"active_primary_shards\" : 0,",
        "  \"active_shards\" : 0,",
        "  \"relocating_shards\" : 0,",
        "  \"initializing_shards\" : 0,",
        "  \"unassigned_shards\" : 0,",
        "  \"unassigned_primary_shards\" : 0,",
        "  \"delayed_unassigned_shards\" : 0,",
        "  \"number_of_pending_tasks\" : 0,",
        "  \"number_of_in_flight_fetch\" : 0,",
        "  \"task_max_waiting_in_queue_millis\" : 0,",
        "  \"active_shards_percent_as_number\" : 100.0",
        "}"
    ]
}

TASK [14. Check if Elasticsearch is working] ***********************************
skipping: [localhost]

TASK [15. Confirm Elasticsearch is working] ************************************
ok: [localhost] => {
    "msg": "Elasticsearch is working correctly"
}

TASK [16. Create test index] ***************************************************
changed: [localhost]

TASK [17. Index a document in Elasticsearch] ***********************************
changed: [localhost]

TASK [18. Wait for indexing to complete] ***************************************
Pausing for 5 seconds
ok: [localhost]

TASK [19. Search for the document in Elasticsearch] ****************************
ok: [localhost]

TASK [20. Display search result] ***********************************************
ok: [localhost] => {
    "search_document.stdout_lines": [
        "{\"took\":62,\"timed_out\":false,\"_shards\":{\"total\":1,\"successful\":1,\"skipped\":0,\"failed\":0},\"hits\":{\"total\":{\"value\":1,\"relation\":\"eq\"},\"max_score\":0.2876821,\"hits\":[{\"_index\":\"test\",\"_id\":\"q5_dXJUB0UxU98p_o2ru\",\"_score\":0.2876821,\"_source\":{\"title\": \"Test Document\", \"content\": \"This is a test document for Elasticsearch.\"}}]}}"
    ]
}

TASK [21. Check if document indexing and search is working] ********************
skipping: [localhost]

TASK [22. Confirm Elasticsearch indexing and search is working] ****************
ok: [localhost] => {
    "msg": "Elasticsearch indexing and search is working correctly"
}

TASK [23. Clean up test index] *************************************************
changed: [localhost]

TASK [24. Display final status] ************************************************
ok: [localhost] => {
    "msg": [
        "Elasticsearch setup completed successfully.",
        "Elasticsearch is deployed in the 'elasticsearch' namespace.",
        "The Elasticsearch service is named 'elasticsearch'.",
        "Use 'kubectl get pods -n elasticsearch' to view the Elasticsearch pods.",
        "Use 'kubectl get svc -n elasticsearch' to view the Elasticsearch service details."
    ]
}

PLAY RECAP *********************************************************************
localhost                  : ok=21   changed=4    unreachable=0    failed=0    skipped=3    rescued=0    ignored=0   

---------- Installation Summary ----------
Test connection: OK
Setup Elasticsearch: OK
All steps completed successfully.
./01-default-apps/07-setup-elasticsearch.sh completed successfully.
---------------------------------------------------
Processing directory: ./02-adm-apps
Running ./02-adm-apps/03-setup-pgadmin.sh with target-host: rancher-desktop...
Starting pgAdmin setup on rancher-desktop
---------------------------------------------------
Switched to context "rancher-desktop".
Applying pgAdmin ConfigMap...
configmap/pgadmin-settings created
Running on Rancher Desktop - using local deployment
Running playbook for Setup pgAdmin...
ERROR! We were unable to read either as JSON nor YAML, these are the errors we got from each:
JSON: Expecting value: line 1 column 1 (char 0)

Syntax Error while loading YAML.
  could not find expected ':'. while scanning a simple key
  in "<unicode string>", line 7, column 1
could not find expected ':'
  in "<unicode string>", line 8, column 1

The error appears to be in '/mnt/urbalurbadisk/ansible/playbooks/641-adm-pgadmin.yml': line 8, column 1, but may
be elsewhere in the file depending on the exact syntax problem.

The offending line appears to be:

-# 1. Deploys pgAdmin using Helm
+# 1. Applies the pgAdmin ConfigMap (640-pgadmin-configmap.yaml)
^ here
---------- Installation Summary ----------
Setup pgAdmin: OK
All steps completed successfully.
./02-adm-apps/03-setup-pgadmin.sh completed successfully.
---------------------------------------------------
---------- Provisioning Summary: ./provision-kubernetes.sh ----------
02-adm-apps:
  03-setup-pgadmin.sh Success
  

01-default-apps:
  07-setup-elasticsearch.sh Success
  05-cloud-setup-postgres.sh Success
  06-setup-redis.sh Success
  

All scripts completed successfully.
Provisioning Kubernetes completed successfully.

Rancher Desktop setup completed successfully.

```