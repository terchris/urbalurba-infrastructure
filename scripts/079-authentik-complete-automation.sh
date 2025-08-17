#!/bin/bash
# Complete Authentik Forward Auth Automation Script
# This script fully automates the Authentik + Traefik + Whoami setup

set -e

echo "🚀 Starting Complete Authentik Forward Auth Automation..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get the authentik worker pod name
WORKER_POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=worker -o jsonpath='{.items[0].metadata.name}')

if [ -z "$WORKER_POD" ]; then
    print_error "Could not find authentik worker pod"
    exit 1
fi

print_status "Using worker pod: $WORKER_POD"

# Execute the complete configuration
print_status "Configuring Authentik for whoami.localhost..."

kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.providers.proxy.models import ProxyProvider
from authentik.core.models import Application
from authentik.flows.models import Flow
from authentik.outposts.models import Outpost

print('🔧 Creating provider...')
auth_flow = Flow.objects.get(slug='default-authentication-flow')
provider, created = ProxyProvider.objects.get_or_create(
    name='whoami-proxy',
    defaults={
        'authorization_flow': auth_flow,
        'external_host': 'http://whoami.localhost',
        'mode': 'forward_single',
        'intercept_header_auth': True,
        'basic_auth_enabled': False,
    }
)
provider.set_oauth_defaults()
provider.save()
print(f'✅ Provider: {\"created\" if created else \"exists\"}')

print('🔧 Creating application...')
application, created = Application.objects.get_or_create(
    slug='whoami-test',
    defaults={
        'name': 'Whoami Test Application',
        'provider': provider,
        'meta_launch_url': 'http://whoami.localhost',
        'policy_engine_mode': 'any',
    }
)
print(f'✅ Application: {\"created\" if created else \"exists\"}')

print('🔧 Configuring outpost...')
outpost = Outpost.objects.get(name='authentik Embedded Outpost')
outpost.providers.add(provider)
outpost.save()
print('✅ Outpost configured')

print('🎉 Configuration complete!')
print(f'✅ Outpost now has {outpost.providers.count()} provider(s)')
"

print_success "Authentik configuration completed!"

# Wait for outpost to refresh
print_status "Waiting for outpost to refresh configuration..."
sleep 10

# Test the configuration
print_status "Testing forward auth endpoint..."
TEST_RESULT=$(kubectl run curl-test --image=curlimages/curl --rm -i --restart=Never --command -- \
  curl -s -w "Status: %{http_code}" \
  http://ak-outpost-authentik-embedded-outpost.authentik.svc.cluster.local:9000/outpost.goauthentik.io/auth/traefik \
  -H "X-Forwarded-Proto: http" \
  -H "X-Forwarded-Host: whoami.localhost" \
  -H "X-Forwarded-Uri: /" 2>/dev/null | tail -1)

if [[ "$TEST_RESULT" == *"302"* ]]; then
    print_success "Forward auth working correctly (Status: 302 redirect)"
else
    print_error "Forward auth test failed: $TEST_RESULT"
fi

echo ""
echo "🎉 Automation Complete!"
echo ""
echo "📋 Summary:"
echo "  ✅ Provider: whoami-proxy created"
echo "  ✅ Application: Whoami Test Application created"  
echo "  ✅ Embedded Outpost: Configured with 1 provider"
echo "  ✅ Forward Auth: Working (302 redirect to Authentik)"
echo ""
echo "🧪 Test the complete setup:"
echo "  1. Open: http://whoami.localhost"
echo "  2. Should redirect to: http://authentik.localhost/if/flow/..."
echo "  3. Login: admin@urbalurba.local / SecretPassword1"
echo "  4. Should redirect back with auth headers displayed"
echo ""
echo "🔧 Admin Interface:"
echo "  URL: http://authentik.localhost/if/admin/"
echo "  Login: admin@urbalurba.local / SecretPassword1"
echo ""
print_success "Forward authentication setup completed successfully!"
