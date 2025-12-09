# Integration Platform

```mermaid
graph TB
    CLOUD["☁️ Internet"]
    
    FIREWALL["🛡️ Azure Firewall"]
    
    classDef prodSecure stroke:#d63031,stroke-width:5px
    
    subgraph "Prod Shared Services"
        subgraph "dev-sharedservices"
            FRONTDOORDEV["🚪 Azure Front Door<br/>(Dev)"]
            APIMDEV["🔧 APIM-Dev"]
            PORTALDEV["👨‍💻 Developer Portal<br/>(Dev)"]
            SERVICEBUSDEV["🚌 Service Bus<br/>(Dev)"]
        end
        
        subgraph "test-sharedservices"
            FRONTDOORTEST["🚪 Azure Front Door<br/>(Test)"]
            APIMTEST["🔧 APIM-Test"]
            PORTALTEST["👨‍💻 Developer Portal<br/>(Test)"]
            SERVICEBUSTEST["🚌 Service Bus<br/>(Test)"]
        end
        
        subgraph "prod-sharedservices"
            FRONTDOORPROD["🚪 Azure Front Door<br/>(Prod)"]
            APIMPROD["🔧 APIM-Prod"]
            PORTALPROD["👨‍💻 Developer Portal<br/>(Prod)"]
            SERVICEBUSPROD["🚌 Service Bus<br/>(Prod)"]
            REGISTRYPROD["📦 Container Registry<br/>(Prod)"]
            CERTRENEWPROD["🔐 Certificate Renew<br/>(Prod)"]
        end
    end
    
    %% Connections
    CLOUD --> FIREWALL
    FIREWALL --> FRONTDOORDEV
    FIREWALL --> FRONTDOORTEST
    FIREWALL --> FRONTDOORPROD
    
    FRONTDOORDEV --> APIMDEV
    FRONTDOORTEST --> APIMTEST
    FRONTDOORPROD --> APIMPROD
    
    APIMDEV --> PORTALDEV
    APIMTEST --> PORTALTEST
    APIMPROD --> PORTALPROD
    
    class SERVICEBUSPROD,APIMPROD prodSecure
```

## Alternative Flow Diagram Version

```mermaid
flowchart LR
    CLOUD["☁️ Internet"]
    FIREWALL["🛡️ Azure Firewall"]
    
    classDef prodSecure stroke:#d63031,stroke-width:5px
    
    subgraph PSS["🏢 Prod Shared Services"]
        direction TB
        subgraph DEV["dev-sharedservices"]
            direction TB
            FRONTDOORDEV["🚪 Azure Front Door<br/>(Dev)"]
            APIMDEV["🔧 APIM-Dev"]
            PORTALDEV["👨‍💻 Developer Portal<br/>(Dev)"]
            SERVICEBUSDEV["🚌 Service Bus<br/>(Dev)"]
        end
        
        subgraph TEST["test-sharedservices"]
            direction TB
            FRONTDOORTEST["🚪 Azure Front Door<br/>(Test)"]
            APIMTEST["🔧 APIM-Test"]
            PORTALTEST["👨‍💻 Developer Portal<br/>(Test)"]
            SERVICEBUSTEST["🚌 Service Bus<br/>(Test)"]
        end
        
        subgraph PROD["prod-sharedservices"]
            direction TB
            FRONTDOORPROD["🚪 Azure Front Door<br/>(Prod)"]
            APIMPROD["🔧 APIM-Prod"]
            PORTALPROD["👨‍💻 Developer Portal<br/>(Prod)"]
            SERVICEBUSPROD["🚌 Service Bus<br/>(Prod)"]
            REGISTRYPROD["📦 Container Registry<br/>(Prod)"]
            CERTRENEWPROD["🔐 Certificate Renew<br/>(Prod)"]
        end
    end
    
    CLOUD --> FIREWALL
    FIREWALL --> FRONTDOORDEV
    FIREWALL --> FRONTDOORTEST
    FIREWALL --> FRONTDOORPROD
    
    FRONTDOORDEV --> APIMDEV
    FRONTDOORTEST --> APIMTEST
    FRONTDOORPROD --> APIMPROD
    
    APIMDEV --> PORTALDEV
    APIMTEST --> PORTALTEST
    APIMPROD --> PORTALPROD
    
    class SERVICEBUSPROD,APIMPROD prodSecure
```