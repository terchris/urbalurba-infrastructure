# Azure AKS Manual Setup - Step by Step Plan

This document provides manual commands to test Azure AKS deployment before creating automated scripts.

## Prerequisites

- You have already run `install-rancher.sh` on your host machine
- The provision-host container is running
- You are working inside the provision-host container

## Step 0: Enter Provision-Host Container

On your host machine:
```bash
docker exec -it provision-host bash
```

Verify you're in the right place:
```bash
pwd
# Should show: /mnt/urbalurbadisk

ls -la
# Should show the urbalurba-infrastructure files
```

## Step 1: Configure Azure Variables

Edit the configuration file with your specific values:
```bash
# Edit the config file
nano /mnt/urbalurbadisk/hosts/azure-aks/azure-aks-config.sh
```

Update these values:
- `TENANT_ID`: Your Azure tenant ID
- `SUBSCRIPTION_ID`: Your Azure subscription ID  
- Adjust `RESOURCE_GROUP`, `CLUSTER_NAME`, `NODE_COUNT`, `NODE_SIZE` as needed

Then source the variables:
```bash
source /mnt/urbalurbadisk/hosts/azure-aks/azure-aks-config.sh
```

Verify variables:
```bash
echo "Subscription: $SUBSCRIPTION_ID"
echo "Resource Group: $RESOURCE_GROUP"
echo "Cluster Name: $CLUSTER_NAME"
```

## Step 2: Azure Login and PIM Activation

### 2.1 Login to Azure
```bash
az login --tenant $TENANT_ID --use-device-code
```
- Follow the device code instructions
- Open browser and enter the code

```plaintext
To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code XXXXXXXX to authenticate.

Retrieving subscriptions for the selection...

[Tenant and subscription selection]

No     Subscription name                     Subscription ID                       Tenant
-----  ------------------------------------  ------------------------------------  ------------------------------------
[1]    Pay-as-you-go                         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[2]    DEV - AZURE INTEGRATIONS - AZ - ...   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[3]    PROD - AZURE INTEGRATIONS - AZ - ...  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[4]    PROD - IT - AZ - ORGANIZATION         xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[5]    PROD - NYSS - AZ - ORGANIZATION       xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[6] *  PROD - SHARED SERVICES - AZ - ORG...  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[7]    SANDBOX - PROJECT1 - AZ - ORGANI...   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[8]    SANDBOX - TAILSCALE DEMO - AZ - O...   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
[9]    TEST - AZURE INTEGRATIONS - AZ - ...   xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx  xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

The default is marked with an *; the default tenant is 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx' and subscription is 'PROD - SHARED SERVICES - AZ - ORGANIZATION' (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx).

Select a subscription and tenant (Type a number or Enter for no changes): 8

Tenant: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
Subscription: SANDBOX - TAILSCALE DEMO - AZ - ORGANIZATION (xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx)

[Announcements]
With the new Azure CLI login experience, you can select the subscription you want to use more easily. Learn more about it and its configuration at https://go.microsoft.com/fwlink/?linkid=2271236

If you encounter any problem, please open an issue at https://aka.ms/azclibug

[Warning] The login output has been updated. Please be aware that it no longer displays the full list of available subscriptions by default.
```

Verify login:
```bash
az account show
```

```plaintext
{
  "environmentName": "AzureCloud",
  "homeTenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "id": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "isDefault": true,
  "managedByTenants": [],
  "name": "SANDBOX - TAILSCALE DEMO - AZ - ORGANIZATION",
  "state": "Enabled",
  "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "user": {
    "name": "user@organization.com",
    "type": "user"
  }
}
```


### 2.2 Set Subscription
```bash
az account set --subscription $SUBSCRIPTION_ID
```

Verify subscription:
```bash
az account show --query name -o tsv
```

```plaintext
SANDBOX - TAILSCALE DEMO - AZ - ORGANIZATION
```

### 2.3 Check PIM Role
Check if you have Contributor role:
```bash
az role assignment list \
  --assignee $(az account show --query user.name -o tsv) \
  --scope "/subscriptions/$SUBSCRIPTION_ID" \
  --query "[?roleDefinitionName=='Contributor'].roleDefinitionName" \
  -o tsv
```

If output is empty, you need to activate PIM:
1. Open: https://portal.azure.com/?feature.msaljs=true#view/Microsoft_Azure_PIMCommon/ActivationMenuBlade/~/azurerbac
2. Find and activate Contributor role for your subscription
3. Wait 1-2 minutes
4. Run the check command again

When you have activated it will output
```plaintext
Contributor
```

## Step 3: Check Azure Quotas

Before creating resources, check if you have enough quota available.

### 3.1 Check vCPU quota
```bash
az vm list-usage --location $LOCATION --query "[?name.value=='cores'].{Name:name.localizedValue,Current:currentValue,Limit:limit}" -o table
```

Expected output:
```plaintext
Name              Current    Limit
--------------  ---------  -------
Total Regional vCPUs    X       XX
```

### 3.2 Check specific VM family quota (B-Series)
```bash
az vm list-usage --location $LOCATION --query "[?contains(name.value,'standardBSFamily')].{Name:name.localizedValue,Current:currentValue,Limit:limit}" -o table
```

Expected output:
```plaintext
Name                              Current    Limit
------------------------------  ---------  -------
Standard BS Family vCPUs              X       XX
```

### 3.3 Calculate and validate requirements

use the automated quota check script:
```bash
./check-aks-quota.sh
```

This script will:
- Auto-load configuration from azure-aks-config.sh
- Check both VM family and total regional quotas
- Provide clear pass/fail results with exit codes
- Suggest solutions if quota is insufficient

If quota check fails, options include:
1. Use fewer nodes: Edit `NODE_COUNT=1` in config file
2. Use smaller VMs: Edit `NODE_SIZE="Standard_B1ms"` in config file  
3. Delete other resources in the region
4. Request quota increase

### 3.4 Check for existing VMs consuming quota
```bash
az vm list --query "[?location=='$LOCATION'].{Name:name,Size:hardwareProfile.vmSize,State:powerState,ResourceGroup:resourceGroup}" -o table
```

This shows VMs that might be consuming your quota.

## Step 4: Create Resource Group

Check if resource group exists:
```bash
az group show --name $RESOURCE_GROUP 2>/dev/null
```

If it doesn't exist, create it:
```bash
az group create \
  --name $RESOURCE_GROUP \
  --location $LOCATION \
  --tags $TAGS
```

```plaintext
{
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/rg-sandbox-aks-weu",
  "location": "westeurope",
  "managedBy": null,
  "name": "rg-sandbox-aks-weu",
  "properties": {
    "provisioningState": "Succeeded"
  },
  "tags": {
    "CostCenter": "IT",
    "Environment": "Sandbox",
    "Project": "kubernetes-test",
    "businessContact": "user@organization.com",
    "opsHours": "no-alerts",
    "opsTeam": "no",
    "technicalContact": "user@organization.com",
    "workload": "tailscale"
  },
  "type": "Microsoft.Resources/resourceGroups"
}
```

Verify creation:
```bash
az group show --name $RESOURCE_GROUP --query name -o tsv
```

´´´plaintext
rg-urbalurba-aks-weu
```



## Step 5: Create AKS Cluster

### 5.1 Check if cluster already exists
```bash
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME 2>/dev/null
```

### 5.2 Create the cluster (if it doesn't exist)

**Option A: Minimal Sandbox (lowest cost)**
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --location $LOCATION \
  --network-plugin azure \
  --generate-ssh-keys \
  --enable-managed-identity \
  --tier free \
  --node-osdisk-size 30 \
  --tags $TAGS
```

**Option B: Development Environment (recommended for actual development)**
```bash
az aks create \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --node-count $NODE_COUNT \
  --node-vm-size $NODE_SIZE \
  --location $LOCATION \
  --network-plugin azure \
  --network-policy azure \
  --generate-ssh-keys \
  --enable-managed-identity \
  --enable-cluster-autoscaler \
  --min-count 1 \
  --max-count 3 \
  --enable-addons monitoring \
  --tier free \
  --node-osdisk-size 30 \
  --tags $TAGS
```

```plaintext
docker_bridge_cidr is not a known attribute of class <class 'azure.mgmt.containerservice.models._models_py3.ContainerServiceNetworkProfile'> and will be ignored
{
  "aadProfile": null,
  "addonProfiles": {
    "omsagent": {
      "config": {
        "logAnalyticsWorkspaceResourceID": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/DefaultResourceGroup-WEU/providers/Microsoft.OperationalInsights/workspaces/DefaultWorkspace-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx-WEU",
        "useAADAuth": "true"
      },
      "enabled": true,
      "identity": null
    }
  },
  "agentPoolProfiles": [
    {
      "availabilityZones": null,
      "capacityReservationGroupId": null,
      "count": 2,
      "creationData": null,
      "currentOrchestratorVersion": "1.32.6",
      "eTag": null,
      "enableAutoScaling": true,
      "enableEncryptionAtHost": false,
      "enableFips": false,
      "enableNodePublicIp": false,
      "enableUltraSsd": false,
      "gatewayProfile": null,
      "gpuInstanceProfile": null,
      "gpuProfile": null,
      "hostGroupId": null,
      "kubeletConfig": null,
      "kubeletDiskType": "OS",
      "linuxOsConfig": null,
      "maxCount": 3,
      "maxPods": 30,
      "messageOfTheDay": null,
      "minCount": 1,
      "mode": "System",
      "name": "nodepool1",
      "networkProfile": null,
      "nodeImageVersion": "AKSUbuntu-2204gen2containerd-202508.11.0",
      "nodeLabels": null,
      "nodePublicIpPrefixId": null,
      "nodeTaints": null,
      "orchestratorVersion": "1.32",
      "osDiskSizeGb": 30,
      "osDiskType": "Ephemeral",
      "osSku": "Ubuntu",
      "osType": "Linux",
      "podIpAllocationMode": null,
      "podSubnetId": null,
      "powerState": {
        "code": "Running"
      },
      "provisioningState": "Succeeded",
      "proximityPlacementGroupId": null,
      "scaleDownMode": "Delete",
      "scaleSetEvictionPolicy": null,
      "scaleSetPriority": null,
      "securityProfile": {
        "enableSecureBoot": false,
        "enableVtpm": false
      },
      "spotMaxPrice": null,
      "status": null,
      "tags": null,
      "type": "VirtualMachineScaleSets",
      "upgradeSettings": {
        "drainTimeoutInMinutes": null,
        "maxSurge": "10%",
        "maxUnavailable": "0",
        "nodeSoakDurationInMinutes": null,
        "undrainableNodeBehavior": null
      },
      "virtualMachineNodesStatus": null,
      "virtualMachinesProfile": null,
      "vmSize": "Standard_B2ms",
      "vnetSubnetId": null,
      "windowsProfile": null,
      "workloadRuntime": null
    }
  ],
  "aiToolchainOperatorProfile": null,
  "apiServerAccessProfile": null,
  "autoScalerProfile": {
    "balanceSimilarNodeGroups": "false",
    "daemonsetEvictionForEmptyNodes": false,
    "daemonsetEvictionForOccupiedNodes": true,
    "expander": "random",
    "ignoreDaemonsetsUtilization": false,
    "maxEmptyBulkDelete": "10",
    "maxGracefulTerminationSec": "600",
    "maxNodeProvisionTime": "15m",
    "maxTotalUnreadyPercentage": "45",
    "newPodScaleUpDelay": "0s",
    "okTotalUnreadyCount": "3",
    "scaleDownDelayAfterAdd": "10m",
    "scaleDownDelayAfterDelete": "10s",
    "scaleDownDelayAfterFailure": "3m",
    "scaleDownUnneededTime": "10m",
    "scaleDownUnreadyTime": "20m",
    "scaleDownUtilizationThreshold": "0.5",
    "scanInterval": "10s",
    "skipNodesWithLocalStorage": "false",
    "skipNodesWithSystemPods": "true"
  },
  "autoUpgradeProfile": {
    "nodeOsUpgradeChannel": "NodeImage",
    "upgradeChannel": null
  },
  "azureMonitorProfile": {
    "metrics": null
  },
  "azurePortalFqdn": "aks-cluster-rg-sandbox-aks-w-xxxxxxxx-xxxxxxxx.portal.hcp.westeurope.azmk8s.io",
  "bootstrapProfile": {
    "artifactSource": "Direct",
    "containerRegistryId": null
  },
  "currentKubernetesVersion": "1.32.6",
  "disableLocalAccounts": false,
  "diskEncryptionSetId": null,
  "dnsPrefix": "aks-cluster-rg-sandbox-aks-w-xxxxxxxx",
  "eTag": null,
  "enableRbac": true,
  "extendedLocation": null,
  "fqdn": "aks-cluster-rg-sandbox-aks-w-xxxxxxxx-xxxxxxxx.hcp.westeurope.azmk8s.io",
  "fqdnSubdomain": null,
  "httpProxyConfig": null,
  "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/rg-sandbox-aks-weu/providers/Microsoft.ContainerService/managedClusters/aks-urbalurba-sandbox",
  "identity": {
    "delegatedResources": null,
    "principalId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "tenantId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
    "type": "SystemAssigned",
    "userAssignedIdentities": null
  },
  "identityProfile": {
    "kubeletidentity": {
      "clientId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "objectId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "resourceId": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourcegroups/MC_rg-sandbox-aks-weu_aks-urbalurba-sandbox_westeurope/providers/Microsoft.ManagedIdentity/userAssignedIdentities/aks-urbalurba-sandbox-agentpool"
    }
  },
  "ingressProfile": null,
  "kind": "Base",
  "kubernetesVersion": "1.32",
  "linuxProfile": {
    "adminUsername": "azureuser",
    "ssh": {
      "publicKeys": [
        {
          "keyData": "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ[REDACTED_SSH_KEY]"
        }
      ]
    }
  },
  "location": "westeurope",
  "maxAgentPools": 100,
  "metricsProfile": {
    "costAnalysis": {
      "enabled": false
    }
  },
  "name": "aks-urbalurba-sandbox",
  "networkProfile": {
    "advancedNetworking": null,
    "dnsServiceIp": "10.0.0.10",
    "ipFamilies": [
      "IPv4"
    ],
    "loadBalancerProfile": {
      "allocatedOutboundPorts": null,
      "backendPoolType": "nodeIPConfiguration",
      "effectiveOutboundIPs": [
        {
          "id": "/subscriptions/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/resourceGroups/MC_rg-sandbox-aks-weu_aks-urbalurba-sandbox_westeurope/providers/Microsoft.Network/publicIPAddresses/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
          "resourceGroup": "MC_rg-sandbox-aks-weu_aks-urbalurba-sandbox_westeurope"
        }
      ],
      "enableMultipleStandardLoadBalancers": null,
      "idleTimeoutInMinutes": null,
      "managedOutboundIPs": {
        "count": 1,
        "countIpv6": null
      },
      "outboundIPs": null,
      "outboundIpPrefixes": null
    },
    "loadBalancerSku": "standard",
    "natGatewayProfile": null,
    "networkDataplane": "azure",
    "networkMode": null,
    "networkPlugin": "azure",
    "networkPluginMode": null,
    "networkPolicy": "azure",
    "outboundType": "loadBalancer",
    "podCidr": null,
    "podCidrs": null,
    "serviceCidr": "10.0.0.0/16",
    "serviceCidrs": [
      "10.0.0.0/16"
    ],
    "staticEgressGatewayProfile": null
  },
  "nodeProvisioningProfile": {
    "defaultNodePools": "Auto",
    "mode": "Manual"
  },
  "nodeResourceGroup": "MC_rg-sandbox-aks-weu_aks-urbalurba-sandbox_westeurope",
  "nodeResourceGroupProfile": null,
  "oidcIssuerProfile": {
    "enabled": false,
    "issuerUrl": null
  },
  "podIdentityProfile": null,
  "powerState": {
    "code": "Running"
  },
  "privateFqdn": null,
  "privateLinkResources": null,
  "provisioningState": "Succeeded",
  "publicNetworkAccess": null,
  "resourceGroup": "rg-sandbox-aks-weu",
  "resourceUid": "xxxxxxxxxxxxxxxxxxxxxxxx",
  "securityProfile": {
    "azureKeyVaultKms": null,
    "customCaTrustCertificates": null,
    "defender": null,
    "imageCleaner": null,
    "workloadIdentity": null
  },
  "serviceMeshProfile": null,
  "servicePrincipalProfile": {
    "clientId": "msi",
    "secret": null
  },
  "sku": {
    "name": "Base",
    "tier": "Free"
  },
  "status": null,
  "storageProfile": {
    "blobCsiDriver": null,
    "diskCsiDriver": {
      "enabled": true
    },
    "fileCsiDriver": {
      "enabled": true
    },
    "snapshotController": {
      "enabled": true
    }
  },
  "supportPlan": "KubernetesOfficial",
  "systemData": null,
  "tags": {
    "CostCenter": "IT",
    "Environment": "Sandbox",
    "Project": "kubernetes-test",
    "businessContact": "user@organization.com",
    "opsHours": "no-alerts",
    "opsTeam": "no",
    "technicalContact": "user@organization.com",
    "workload": "tailscale"
  },
  "type": "Microsoft.ContainerService/ManagedClusters",
  "upgradeSettings": null,
  "windowsProfile": {
    "adminPassword": null,
    "adminUsername": "azureuser",
    "enableCsiProxy": true,
    "gmsaProfile": null,
    "licenseType": null
  },
  "workloadAutoScalerProfile": {
    "keda": null,
    "verticalPodAutoscaler": null
  }
}
```


This will take 5-10 minutes.

**Key differences:**
- **Option A**: Bare minimum for testing AKS functionality
- **Option B**: Includes autoscaling (1-3 nodes) and monitoring for development work 

### 5.3 Verify cluster creation
```bash
az aks show --resource-group $RESOURCE_GROUP --name $CLUSTER_NAME --query provisioningState -o tsv
```

```plaintext
Succeeded
```

## Step 6: Get AKS Credentials

### 6.1 Get kubeconfig
```bash
az aks get-credentials \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --file /mnt/urbalurbadisk/kubeconfig/azure-aks-kubeconf \
  --overwrite-existing
```

```plaintext
Merged "aks-urbalurba-sandbox" as current context in /mnt/urbalurbadisk/kubeconfig/azure-aks-kubeconf
````


### 6.2 Test kubectl access
```bash
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/azure-aks-kubeconf
kubectl get nodes
```

```plaintext
NAME                                STATUS   ROLES    AGE     VERSION
aks-nodepool1-22064185-vmss000000   Ready    <none>   3m21s   v1.32.6
aks-nodepool1-22064185-vmss000001   Ready    <none>   3m21s   v1.32.6
```

You should see 2 node in Ready state.


## Step 7: Merge Kubeconfig Files

### 7.1 Run ansible playbook to merge configs
```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/04-merge-kubeconf.yml
```

### 7.2 Set KUBECONFIG environment variable
```bash
export KUBECONFIG=/mnt/urbalurbadisk/kubeconfig/kubeconf-all
```

### 7.3 Verify contexts
```bash
kubectl config get-contexts
```

You should see both:
- rancher-desktop
- azure-aks

### 7.4 Switch to AKS context
```bash
kubectl config use-context azure-aks
kubectl get nodes
```

## Step 8: Apply Storage Class Alias

### 8.1 Apply storage class alias
```bash
kubectl apply -f hosts/azure-aks/manifests-overrides/000-storage-class-azure-alias.yaml
```

### 8.2 Verify storage class
```bash
kubectl get storageclass
```

```plaintext
get storageclass
NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
azurefile               file.csi.azure.com   Delete          Immediate              true                   18m
azurefile-csi           file.csi.azure.com   Delete          Immediate              true                   18m
azurefile-csi-premium   file.csi.azure.com   Delete          Immediate              true                   18m
azurefile-premium       file.csi.azure.com   Delete          Immediate              true                   18m
default (default)       disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   18m
local-path              disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   117s
managed                 disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   18m
managed-csi             disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   18m
managed-csi-premium     disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   18m
managed-premium         disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   18m
microk8s-hostpath       disk.csi.azure.com   Delete          WaitForFirstConsumer   true                   117s
```

You should see `microk8s-hostpath` in the list.

## Step 9: Deploy Configuration Secrets

### 9.1 Apply kubernetes secrets configuration
```bash
kubectl apply -f /mnt/urbalurbadisk/topsecret/kubernetes/kubernetes-secrets.yml
```

```plaintext
secret/urbalurba-secrets created
secret/ghcr-credentials created
secret/cloudflared-credentials created
secret/pgadmin4-password created
namespace/ai created
secret/urbalurba-secrets created
namespace/argocd created
secret/argocd-secret created
namespace/jupyterhub created
secret/urbalurba-secrets created
namespace/unity-catalog created
secret/urbalurba-secrets created
namespace/monitoring created
secret/urbalurba-secrets created
namespace/authentik created
secret/urbalurba-secrets created
```

This deploys all the configuration variables and secrets that services depend on.

### 9.2 Verify secrets deployment
```bash
kubectl get secrets
kubectl get configmaps
```

## Step 10: Install Traefik Ingress Controller

AKS doesn't come with Traefik pre-installed like Rancher Desktop. We need to install it manually.

### 10.1 Add Traefik Helm repository
```bash
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

### 10.2 Install Traefik
```bash
helm install traefik traefik/traefik \
  -f /mnt/urbalurbadisk/manifests/003-traefik-config.yaml \
  --namespace kube-system
```

```plaintext
NAME: traefik
LAST DEPLOYED: Fri Sep  5 15:01:16 2025
NAMESPACE: kube-system
STATUS: deployed
REVISION: 1
TEST SUITE: None
NOTES:
traefik with docker.io/traefik:v3.3.2 has been deployed successfully on kube-system namespace !
````


### 10.3 Wait for Traefik to be ready
```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik --timeout=300s -n kube-system
```

### 10.4 Verify Traefik installation
```bash
kubectl get pods -n kube-system | grep traefik
kubectl get services -n kube-system | grep traefik
kubectl get crd | grep traefik
```

```plaintext
traefik-597dd77876-sm28f                            1/1     Running   0             4m14s

traefik                        LoadBalancer   10.0.117.150   4.245.72.239   80:32195/TCP,443:30142/TCP   4m21s

accesscontrolpolicies.hub.traefik.io                         2025-09-05T13:00:14Z
aiservices.hub.traefik.io                                    2025-09-05T13:00:14Z
apiauths.hub.traefik.io                                      2025-09-05T13:00:14Z
apibundles.hub.traefik.io                                    2025-09-05T13:00:15Z
apicatalogitems.hub.traefik.io                               2025-09-05T13:00:15Z
apiplans.hub.traefik.io                                      2025-09-05T13:00:15Z
apiportalauths.hub.traefik.io                                2025-09-05T13:00:15Z
apiportals.hub.traefik.io                                    2025-09-05T13:00:15Z
apiratelimits.hub.traefik.io                                 2025-09-05T13:00:15Z
apis.hub.traefik.io                                          2025-09-05T13:00:16Z
apiversions.hub.traefik.io                                   2025-09-05T13:00:16Z
ingressroutes.traefik.io                                     2025-09-05T13:00:16Z
ingressroutetcps.traefik.io                                  2025-09-05T13:00:16Z
ingressrouteudps.traefik.io                                  2025-09-05T13:00:16Z
managedapplications.hub.traefik.io                           2025-09-05T13:00:16Z
managedsubscriptions.hub.traefik.io                          2025-09-05T13:00:16Z
middlewares.traefik.io                                       2025-09-05T13:00:16Z
middlewaretcps.traefik.io                                    2025-09-05T13:00:17Z
serverstransports.traefik.io                                 2025-09-05T13:00:17Z
serverstransporttcps.traefik.io                              2025-09-05T13:00:17Z
tlsoptions.traefik.io                                        2025-09-05T13:00:17Z
tlsstores.traefik.io                                         2025-09-05T13:00:17Z
traefikservices.traefik.io                                   2025-09-05T13:00:17Z
```


You should see the Traefik pod running and CRDs including `ingressroutes.traefik.io`.


## Step 11: Test Basic Deployment

### 11.1 Deploy nginx using ansible playbook
```bash
cd /mnt/urbalurbadisk
ansible-playbook ansible/playbooks/020-setup-nginx.yml
```

This playbook will:
- Set up web files and storage (PVC)  
- Deploy nginx using Helm with Bitnami chart
- Configure nginx to use the PVC
- Create IngressRoute for external access
- Test connectivity

### 11.2 Verify nginx deployment
```bash
kubectl get pods -l app.kubernetes.io/name=nginx
kubectl get pvc nginx-content-pvc
kubectl get ingressroute nginx-root-catch-all
```

```plaintext

NAME                     READY   STATUS    RESTARTS   AGE
nginx-74595c9df8-c2mll   1/1     Running   0          116s


NAME                STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
nginx-content-pvc   Bound    pvc-b36291f0-6927-4f0b-9dcb-601e2b56c48e   1Gi        RWO            default        <unset>                 55m


NAME                   AGE
nginx-root-catch-all   79s
```

### 11.3 Deploy whoami service
```bash
kubectl apply -f /mnt/urbalurbadisk/manifests/070-whoami-service-and-deployment.yaml
```

### 11.4 Check whoami
```bash
kubectl get pods -l app=whoami
kubectl get svc whoami
```

```plaintext

NAME                     READY   STATUS    RESTARTS   AGE
whoami-dd6bddd44-5vlrl   1/1     Running   0          5m25s

NAME     TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
whoami   ClusterIP   10.0.202.196   <none>        80/TCP    5m32s
```

## Step 12: Context Switching Test

### 12.1 Switch to local
```bash
kubectl config use-context rancher-desktop
kubectl get nodes
```

### 12.2 Switch back to AKS
```bash
kubectl config use-context azure-aks
kubectl get nodes
```

## Troubleshooting

### Issue: PIM role not activated
**Symptom**: Permission denied errors
**Solution**: Activate PIM role in Azure portal, wait 2 minutes

### Issue: kubectl not finding cluster
**Symptom**: `The connection to the server localhost:8080 was refused`
**Solution**: Check KUBECONFIG environment variable

### Issue: Storage class not working
**Symptom**: PVCs stuck in Pending
**Solution**: Check storage class name matches, check node availability

### Issue: External IP not assigned
**Symptom**: Service shows `<pending>` for EXTERNAL-IP
**Solution**: Wait longer, check Azure quota limits

## Step X: Delete and Recreate Cluster (If Needed)

If you need to recreate the cluster with correct configuration:

### X.1 Delete existing cluster
```bash
# Delete the incorrectly named cluster
az aks delete \
  --resource-group rg-sandbox-aks-weu \
  --name aks-urbalurba-sandbox \
  --yes \
  --no-wait
```

### X.2 Wait for deletion (optional)
```bash
# Check deletion status
az aks show \
  --resource-group rg-sandbox-aks-weu \
  --name aks-urbalurba-sandbox \
  --query provisioningState -o tsv 2>/dev/null || echo "Cluster deleted"
```


## Final Cleanup Commands (When Done Testing)

To destroy everything and save costs:

```bash
# Delete the AKS cluster
az aks delete \
  --resource-group $RESOURCE_GROUP \
  --name $CLUSTER_NAME \
  --yes \
  --no-wait

# Optional: Delete the resource group (if empty)
az group delete \
  --name $RESOURCE_GROUP \
  --yes \
  --no-wait
```

## Next Steps

After successfully running these commands manually:
1. Document any issues encountered
2. Create automated scripts based on working commands
3. Add error handling and status checks
4. Create the final `install-azure-aks.sh` script

## Notes for Script Creation

When creating scripts from these commands:
- Add the PIM activation check function from azure-microk8s
- Add error handling after each az command
- Add status reporting like in azure-microk8s scripts
- Include cleanup in case of failures
- Make storage class creation idempotent