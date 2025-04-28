# Infrastructure Overview

This document provides detailed diagrams and explanations of the different infrastructure setups in the Urbalurba system.

## Base Infrastructure

The base infrastructure consists of two main components:
1. The provision-host container that contains all necessary tools
2. A local Kubernetes cluster (either Rancher Desktop or MicroK8s)

:::mermaid
flowchart TD
    subgraph Local_Machine["Local Development Machine"]
        subgraph provision_host["Provision Host Container"]
            direction TB
            kubectl["kubectl"]
            ansible["Ansible"]
            cloud_tools["Cloud Provider Tools"]
            
            %% Force vertical stacking with invisible connections
            kubectl --- ansible --- cloud_tools
            linkStyle 0,1 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
        
        subgraph kubernetes["Local Kubernetes Cluster"]
            direction TB
            k8s_api["Kubernetes API"]
            traefik["Traefik Ingress"]
            core_dns["CoreDNS"]
            metrics["Metrics Server"]
            
            %% Force vertical stacking with invisible connections
            k8s_api --- traefik --- core_dns --- metrics
            linkStyle 2,3,4 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    %% Connections
    kubectl <--> k8s_api
:::

The provision-host container is the central management point for the infrastructure, containing all necessary tools for:
- Kubernetes cluster management
- Infrastructure automation
- Cloud provider integration

The local Kubernetes cluster provides the runtime environment for:
- Container orchestration
- Service discovery
- Load balancing
- Metrics collection

## Production Infrastructure

The production infrastructure extends the base setup by adding:
1. An Azure VM running MicroK8s
2. Tailscale for secure communication between the provision-host and the Azure VM

:::mermaid
flowchart TD
    subgraph Local_Dev["Local Development Machine"]
        subgraph provision_host["Provision Host Container"]
            direction TB
            kubectl["kubectl"]
            ansible["Ansible"]
            cloud_tools["Cloud Provider Tools"]
            tailscale_local["Tailscale Client"]
            
            %% Force vertical stacking with invisible connections
            kubectl --- ansible --- cloud_tools --- tailscale_local
            linkStyle 0,1,2 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    subgraph Azure_Cloud["Azure Cloud"]
        subgraph azure_vm["Azure VM (Ubuntu)"]
            direction TB
            tailscale_vm["Tailscale Client"]
            
            subgraph microk8s["MicroK8s Cluster"]
                direction TB
                k8s_api["Kubernetes API"]
                traefik["Traefik Ingress"]
                core_dns["CoreDNS"]
                metrics["Metrics Server"]
                
                %% Force vertical stacking with invisible connections
                k8s_api --- traefik --- core_dns --- metrics
                linkStyle 3,4,5 stroke-width:0,stroke-opacity:0,fill-opacity:0
            end
            
            %% Force vertical stacking with invisible connections
            tailscale_vm --- microk8s
            linkStyle 6 stroke-width:0,stroke-opacity:0,fill-opacity:0
        end
    end
    
    %% Connections
    cloud_tools <--> azure_vm
    kubectl -. "Secure Connection" .-> k8s_api
    tailscale_local -. "Tailscale VPN" .-> tailscale_vm
:::

The production setup provides:
- Secure communication between local development and production environments
- Scalable Kubernetes cluster in Azure
- Zero-trust networking through Tailscale
- Access control through Tailscale ACL rules

The Azure VM running MicroK8s includes:
- Full Kubernetes cluster capabilities
- High availability options
- Production-grade networking
- Azure cloud integration 