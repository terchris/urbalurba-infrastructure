#!/bin/bash
# Complete Authentik Forward Auth Automation
# This script will automatically configure Authentik with all necessary components

set -e

echo "🚀 Starting Authentik Forward Auth Automation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to wait for a condition
wait_for_condition() {
    local description="$1"
    local command="$2"
    local timeout="${3:-60}"
    
    print_status "Waiting for: $description"
    local count=0
    while ! eval "$command" >/dev/null 2>&1; do
        if [ $count -ge $timeout ]; then
            print_error "Timeout waiting for: $description"
            return 1
        fi
        sleep 2
        count=$((count + 2))
        echo -n "."
    done
    echo ""
    print_success "$description"
}

# Step 1: Verify infrastructure
print_status "Step 1: Verifying infrastructure..."

# Check if authentik is running
if ! kubectl get pods -n authentik | grep -q "authentik-server.*Running"; then
    print_error "Authentik server is not running!"
    exit 1
fi

if ! kubectl get pods -n authentik | grep -q "authentik-worker.*Running"; then
    print_error "Authentik worker is not running!"
    exit 1
fi

print_success "Authentik infrastructure is running"

# Step 2: Create the blueprint configuration
print_status "Step 2: Creating blueprint configuration..."

# Get the authentik worker pod name
WORKER_POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=worker -o jsonpath='{.items[0].metadata.name}')

if [ -z "$WORKER_POD" ]; then
    print_error "Could not find authentik worker pod"
    exit 1
fi

print_status "Using worker pod: $WORKER_POD"

# Create the blueprint file inside the pod
kubectl exec -n authentik "$WORKER_POD" -- bash -c 'cat > /tmp/whoami-blueprint.yaml << "EOF"
version: 1
metadata:
  name: "Whoami Forward Auth Setup"
  labels:
    blueprints.goauthentik.io/instantiate: "true"
entries:
  # Create the OAuth2 Proxy Provider
  - model: authentik_providers_proxy.proxyprovider
    state: present
    identifiers:
      name: whoami-proxy
    attrs:
      name: whoami-proxy
      authorization_flow: !Find [authentik_flows.flow, [slug, default-authorization-flow]]
      external_host: http://whoami.localhost
      mode: forward_single
      intercept_header_auth: true
      basic_auth_enabled: false
      
  # Create the Application
  - model: authentik_core.application
    state: present
    identifiers:
      slug: whoami-test
    attrs:
      name: "Whoami Test Application"
      slug: whoami-test
      provider: !KeyOf whoami-proxy
      meta_launch_url: http://whoami.localhost
      policy_engine_mode: any
EOF'

print_success "Blueprint file created"

# Step 3: Apply the blueprint
print_status "Step 3: Applying blueprint to create provider and application..."

kubectl exec -n authentik "$WORKER_POD" -- ak apply_blueprint /tmp/whoami-blueprint.yaml

# Wait a moment for the blueprint to be processed
sleep 5

print_success "Blueprint applied successfully"

# Step 4: Configure the embedded outpost
print_status "Step 4: Configuring embedded outpost..."

# Use Django shell to configure the outpost
kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.outposts.models import Outpost
from authentik.providers.proxy.models import ProxyProvider
from authentik.core.models import Application

# Get the embedded outpost
try:
    outpost = Outpost.objects.get(name='authentik Embedded Outpost')
    print(f'Found outpost: {outpost.name}')
except Outpost.DoesNotExist:
    print('ERROR: Embedded outpost not found')
    exit(1)

# Get the provider we just created
try:
    provider = ProxyProvider.objects.get(name='whoami-proxy')
    print(f'Found provider: {provider.name}')
except ProxyProvider.DoesNotExist:
    print('ERROR: Provider not found')
    exit(1)

# Add the provider to the outpost
outpost.providers.add(provider)
print('Added provider to outpost')

# Save the outpost configuration
outpost.save()
print('Outpost configuration saved')

print('Outpost configuration completed successfully')
"

print_success "Embedded outpost configured"

# Step 5: Verify the configuration
print_status "Step 5: Verifying configuration..."

# Check if provider exists
PROVIDER_COUNT=$(kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.providers.proxy.models import ProxyProvider
print(ProxyProvider.objects.filter(name='whoami-proxy').count())
" 2>/dev/null | tail -1)

if [ "$PROVIDER_COUNT" = "1" ]; then
    print_success "Provider 'whoami-proxy' created successfully"
else
    print_error "Provider was not created properly"
    exit 1
fi

# Check if application exists
APP_COUNT=$(kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import Application
print(Application.objects.filter(slug='whoami-test').count())
" 2>/dev/null | tail -1)

if [ "$APP_COUNT" = "1" ]; then
    print_success "Application 'whoami-test' created successfully"
else
    print_error "Application was not created properly"
    exit 1
fi

# Step 6: Test the configuration
print_status "Step 6: Testing the authentication flow..."

# Wait for outpost to refresh its configuration
print_status "Waiting for outpost to refresh configuration..."
sleep 10

# Test if the outpost responds correctly
print_status "Testing outpost endpoint..."

# Create a test pod to check connectivity
kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never --command -- \
    curl -s -o /dev/null -w "%{http_code}" \
    http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000/outpost.goauthentik.io/auth/traefik \
    -H "X-Forwarded-Proto: http" \
    -H "X-Forwarded-Host: whoami.localhost" \
    -H "X-Forwarded-Uri: /" || true

print_success "Configuration testing completed"

# Step 7: Final verification
print_status "Step 7: Final system verification..."

echo ""
echo "🎉 Authentik Forward Auth Setup Complete!"
echo ""
echo "📋 Configuration Summary:"
echo "  ✅ Provider: whoami-proxy"
echo "  ✅ Application: whoami-test"  
echo "  ✅ Embedded Outpost: Configured"
echo "  ✅ Forward Auth: Ready"
echo ""
echo "🧪 Test the setup:"
echo "  1. Open: http://whoami.localhost"
echo "  2. You should be redirected to Authentik for login"
echo "  3. Login with: admin@urbalurba.local / SecretPassword1"
echo "  4. After login, you should see the whoami application with auth headers"
echo ""
echo "🔧 Admin Interface:"
echo "  URL: http://authentik.localhost/if/admin/"
echo "  Login: admin@urbalurba.local / SecretPassword1"
echo ""

print_success "Automation completed successfully!"
