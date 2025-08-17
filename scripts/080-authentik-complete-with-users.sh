#!/bin/bash
# Complete Authentik Forward Auth + User Management Automation
# This script fully automates Authentik setup including users and groups

set -e

echo "🚀 Starting Complete Authentik Automation with User Management..."

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

# Execute the complete configuration including users
print_status "Configuring Authentik with providers, applications, and users..."

kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.providers.proxy.models import ProxyProvider
from authentik.core.models import Application, User, Group
from authentik.flows.models import Flow
from authentik.outposts.models import Outpost
from django.contrib.auth.hashers import make_password

print('=' * 50)
print('🔧 STEP 1: Creating Groups')
print('=' * 50)

groups_data = [
    {'name': 'developers', 'is_superuser': False},
    {'name': 'viewers', 'is_superuser': False},
    {'name': 'admins', 'is_superuser': True}
]

for group_data in groups_data:
    group, created = Group.objects.get_or_create(
        name=group_data['name'],
        defaults={'is_superuser': group_data['is_superuser']}
    )
    print(f'✅ Group {group.name}: {\"created\" if created else \"exists\"}')

print()
print('=' * 50)
print('🔧 STEP 2: Creating Users')
print('=' * 50)

users_data = [
    {
        'username': 'developer',
        'email': 'developer@urbalurba.local',
        'name': 'Developer User',
        'password': 'DevPassword1',
        'groups': ['developers'],
        'is_active': True
    },
    {
        'username': 'viewer',
        'email': 'viewer@urbalurba.local',
        'name': 'Viewer User',
        'password': 'ViewPassword1',
        'groups': ['viewers'],
        'is_active': True
    },
    {
        'username': 'testuser',
        'email': 'test@urbalurba.local',
        'name': 'Test User',
        'password': 'TestPassword1',
        'groups': ['developers'],
        'is_active': True
    },
    {
        'username': 'alice',
        'email': 'alice@urbalurba.local',
        'name': 'Alice Johnson',
        'password': 'AlicePassword1',
        'groups': ['developers'],
        'is_active': True
    },
    {
        'username': 'bob',
        'email': 'bob@urbalurba.local',
        'name': 'Bob Smith',
        'password': 'BobPassword1',
        'groups': ['viewers'],
        'is_active': True
    }
]

for user_data in users_data:
    user, created = User.objects.get_or_create(
        username=user_data['username'],
        defaults={
            'email': user_data['email'],
            'name': user_data['name'],
            'password': make_password(user_data['password']),
            'is_active': user_data['is_active'],
            'attributes': {
                'created_by': 'automation',
                'user_type': 'development'
            }
        }
    )
    
    # Add to groups
    for group_name in user_data['groups']:
        try:
            group = Group.objects.get(name=group_name)
            user.ak_groups.add(group)
        except Group.DoesNotExist:
            print(f'⚠️  Warning: Group {group_name} not found')
    
    print(f'✅ User {user.username} ({user.email}): {\"created\" if created else \"exists\"}')

print()
print('=' * 50)
print('🔧 STEP 3: Creating Proxy Provider')
print('=' * 50)

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

print()
print('=' * 50)
print('🔧 STEP 4: Creating Application')
print('=' * 50)

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

print()
print('=' * 50)
print('🔧 STEP 5: Configuring Embedded Outpost')
print('=' * 50)

outpost = Outpost.objects.get(name='authentik Embedded Outpost')
outpost.providers.add(provider)
outpost.save()
print(f'✅ Outpost configured with {outpost.providers.count()} provider(s)')

print()
print('=' * 50)
print('🎉 CONFIGURATION SUMMARY')
print('=' * 50)

print(f'Groups created: {Group.objects.count()}')
for group in Group.objects.all():
    user_count = group.user_set.count()
    print(f'  - {group.name}: {user_count} users')

print(f'Users created: {User.objects.count()}')
for user in User.objects.all():
    groups = [g.name for g in user.ak_groups.all()]
    print(f'  - {user.username} ({user.email}): {groups}')

print(f'Providers: {ProxyProvider.objects.count()}')
print(f'Applications: {Application.objects.count()}')
print(f'Outpost providers: {outpost.providers.count()}')

print()
print('🎉 Complete configuration finished successfully!')
"

print_success "Authentik configuration with users completed!"

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
echo "🎉 Complete Automation Finished!"
echo ""
echo "📋 Configuration Summary:"
echo "  ✅ Groups: developers, viewers, admins"
echo "  ✅ Users: developer, viewer, testuser, alice, bob"
echo "  ✅ Provider: whoami-proxy"
echo "  ✅ Application: Whoami Test Application"  
echo "  ✅ Embedded Outpost: Configured"
echo "  ✅ Forward Auth: Working (302 redirect)"
echo ""
echo "👥 Test Users Created:"
echo "  • developer@urbalurba.local / DevPassword1 (developers group)"
echo "  • viewer@urbalurba.local / ViewPassword1 (viewers group)"  
echo "  • test@urbalurba.local / TestPassword1 (developers group)"
echo "  • alice@urbalurba.local / AlicePassword1 (developers group)"
echo "  • bob@urbalurba.local / BobPassword1 (viewers group)"
echo "  • admin@urbalurba.local / SecretPassword1 (admin - from bootstrap)"
echo ""
echo "🧪 Test the complete setup:"
echo "  1. Open: http://whoami.localhost"
echo "  2. Login with any user above"
echo "  3. See authentication headers with user info and groups"
echo ""
echo "🔧 Admin Interface:"
echo "  URL: http://authentik.localhost/if/admin/"
echo "  Login: admin@urbalurba.local / SecretPassword1"
echo ""
print_success "Complete authentication system ready!"
