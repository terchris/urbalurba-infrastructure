# Starting Urbalurba infrastructure

The urbalurba-infrastructure contains many services and applications. You can decide what the initial state of the urbalurba-infrastructure should be by moving the files in and out of the `not-in-use` folder.
Read the [provision-host-kubernetes-readme.md](provision-host-kubernetes-readme.md) file for more information.

By default the urbalurba-infrastructure is configured to be a development environment and has a webserver and a database.


Starting it up is as easy as running the following command:

```bash
./install-rancher.sh
```

The output is huge and it takes about 30-40 minutes to complete.
At the end you will see something like:

```plaintext
---------- Provisioning Summary: ./provision-kubernetes.sh ----------
09-network:
  01-tailscale-net-start.sh Success
  

01-core-systems:
  020-setup-nginx.sh Success
  

02-databases:
  05-cloud-setup-postgres.sh Success
  

08-development:
  02-setup-argocd.sh Success
  

All scripts completed successfully.
Provisioning Kubernetes completed successfully.
====================  F I N I S H E D  ====================
The provision-host container is all set up and you can log in to it using: docker exec -it provision-host bash
.
Kubernetes in Rancher Desktop is all set up and these are the installed systems:
NAMESPACE     NAME                                               READY       STATUS      CLUSTER-IP   PORTS
argocd        argocd-application-controller-0                    true        Running     10.42.0.25   8082
argocd        argocd-applicationset-controller-786785495-s27gd   true        Running     10.42.0.29   8080,8081,7000
argocd        argocd-redis-58df69cb5-j6cmr                       true        Running     10.42.0.26   6379
argocd        argocd-repo-server-846f9b6bc8-d5tgn                true        Running     10.42.0.27   8081,8084
argocd        argocd-server-84bb58f5d5-7ks2c                     true        Running     10.42.0.28   8080,8083
default       nginx-76668d8b89-pb5p4                             true        Running     10.42.0.19   8080,8443
default       postgresql-0                                       true        Running     10.42.0.23   5432
kube-system   coredns-ff8999cc5-zwlr5                            true        Running     10.42.0.10   53,53,9153
kube-system   helm-install-traefik-crd-bwqxs                     false       Succeeded   <none>       <none>
kube-system   helm-install-traefik-tcw8p                         false       Succeeded   <none>       <none>
kube-system   local-path-provisioner-774c6665dc-l5vmw            true        Running     10.42.0.12   <none>
kube-system   metrics-server-6f4c6675d5-prfzf                    true        Running     10.42.0.11   10250
kube-system   svclb-traefik-939d1c07-fgh2g                       true,true   Running     10.42.0.9    80,443
kube-system   traefik-67bfb46dcb-tv8cw                           true        Running     10.42.0.13   9100,8080,8000,8443
tailscale     operator-7d8c8cd74-8fvqp                           true        Running     10.42.0.30   <none>
.
Tailscale networking is set up for secure access to your infrastructure.
Tailscale IP: 100.83.35.88
.
Connected Tailscale network devices:
urbalurba-operator: 100.68.85.48 (offline)
azure-microk8s: 100.70.232.41 (online)
tecMacDev: 100.83.250.6 (online)
www: 100.99.117.110 (offline)
provision-host: 100.121.39.62 (offline)
provision-host: 100.83.35.88 (self)
.
====================  E N D  O F  I N S T A L L A T I O N  ====================
```


