# Setting up Tailscale Funnel for Kubernetes Ingress

## Executive Summary

We successfully established a secure ingress path into a Kubernetes cluster using Tailscale Funnel. This solution allows external access to services in the cluster without requiring public IP addresses or opening ports on the firewall. Traffic flows securely through Tailscale's encrypted network before reaching the Kubernetes cluster's Traefik ingress controller.

## Architecture

```
External Request → Tailscale Funnel → Traefik Ingress Controller → Kubernetes Service
```

## Implementation Steps

### 1. Set up Tailscale Operator in Kubernetes

```bash
# Create a namespace for Tailscale
kubectl create namespace tailscale

# Create a secret with OAuth credentials
kubectl create secret -n tailscale generic tailscale-auth \
  --from-literal=oauth.clientId=YOUR_OAUTH_CLIENT_ID \
  --from-literal=oauth.clientSecret=YOUR_OAUTH_CLIENT_SECRET

# Add Tailscale Helm repository
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm repo update

# Install the Tailscale operator
helm install tailscale-operator tailscale/tailscale-operator \
  --namespace tailscale \
  --set-string oauth.clientId=YOUR_OAUTH_CLIENT_ID \
  --set-string oauth.clientSecret=YOUR_OAUTH_CLIENT_SECRET
```

### 2. Configure Tailscale Funnel for the Traefik Ingress Controller

```bash
# Create an ingress resource in the same namespace as Traefik
cat > traefik-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-ingress
  namespace: kube-system  # Same namespace as Traefik
  annotations:
    tailscale.com/funnel: "true"  # Enable Tailscale Funnel
spec:
  ingressClassName: tailscale
  defaultBackend:
    service:
      name: traefik
      port:
        number: 80
  tls:
    - hosts:
        - rancher-traefik  # Will become rancher-traefik.your-tailnet.ts.net
EOF

kubectl apply -f traefik-ingress.yaml
```

### 3. Create Test Services and Configure Ingress Rules

```bash
# Create a test web deployment
kubectl create deployment test-web --image=nginx -n default

# Expose it as a service
kubectl expose deployment test-web --port=80 -n default

# Add custom content
TEST_POD=$(kubectl get pod -l app=test-web -o name | cut -d/ -f2)
kubectl exec -it $TEST_POD -- bash -c 'echo "<h1>Hello from Tailscale Funnel</h1>" > /usr/share/nginx/html/index.html'
kubectl exec -it $TEST_POD -- bash -c 'mkdir -p /usr/share/nginx/html/test && echo "<h1>This is the test path</h1>" > /usr/share/nginx/html/test/index.html'

# Create ingress rules for the test service
cat > test-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: test-ingress
  namespace: default
spec:
  rules:
  - host: "rancher-traefik.your-tailnet.ts.net"
    http:
      paths:
      - path: /test
        pathType: Prefix
        backend:
          service:
            name: test-web
            port:
              number: 80
EOF

kubectl apply -f test-ingress.yaml

# Create ingress rule for the root path
cat > root-ingress.yaml << EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: root-ingress
  namespace: default
spec:
  rules:
  - host: "rancher-traefik.your-tailnet.ts.net"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: test-web
            port:
              number: 80
EOF

kubectl apply -f root-ingress.yaml
```

## Verification

After setting up the Tailscale Funnel, you can access your services using the Tailscale-provided URL:

```bash
curl --insecure https://rancher-traefik.your-tailnet.ts.net/
curl --insecure https://rancher-traefik.your-tailnet.ts.net/test/
```

## Troubleshooting

### Certificate Issues

When first setting up Tailscale Funnel, you might encounter TLS certificate warnings. These should resolve within 10-15 minutes as the certificate propagates. During testing, you can use:

```bash
# For curl
curl --insecure https://rancher-traefik.your-tailnet.ts.net/

# For browsers
# Click through the advanced options to proceed despite the warning
```

### Checking Status

To verify the Tailscale Funnel configuration:

```bash
# Get the proxy pod name
PROXY_POD=$(kubectl get pods -n tailscale -l tailscale.com/parent-resource-type=ingress,tailscale.com/parent-resource=traefik-ingress -o name | head -1)

# Check Funnel status
kubectl exec -n tailscale $PROXY_POD -- tailscale funnel status

# Check serve status
kubectl exec -n tailscale $PROXY_POD -- tailscale serve status
```

### Ingress Issues

If you encounter 404 errors or other routing problems:

1. Verify the ingress is correctly configured:
   ```bash
   kubectl describe ingress your-ingress-name
   ```

2. Check the Traefik logs:
   ```bash
   kubectl logs -n kube-system deployment/traefik
   ```

3. Verify the Tailscale operator logs:
   ```bash
   kubectl logs -n tailscale deployment/operator
   ```

## Benefits

- **Secure Access**: All traffic is encrypted through the Tailscale network
- **No Public IP Required**: Services remain private but accessible through Tailscale
- **Simple Configuration**: Leverages standard Kubernetes ingress resources
- **Zero Trust**: Access can be controlled through Tailscale ACLs

## Next Steps

- Configure additional services with their own ingress rules
- Set up MagicDNS for easier access
- Implement Tailscale ACLs to control access to specific services
- Consider using Cloudflare for additional security and domain customization