#!/bin/bash
# Authentik User Management Helper
# Provides easy commands for managing users in Authentik

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Get worker pod
WORKER_POD=$(kubectl get pods -n authentik -l app.kubernetes.io/component=worker -o jsonpath='{.items[0].metadata.name}')

if [ -z "$WORKER_POD" ]; then
    print_error "Could not find authentik worker pod"
    exit 1
fi

show_help() {
    echo "Authentik User Management Helper"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Commands:"
    echo "  list-users          List all users and their groups"
    echo "  list-groups         List all groups and their members"
    echo "  create-user         Create a new user (interactive)"
    echo "  reset-password      Reset a user's password (interactive)"
    echo "  add-to-group        Add user to group (interactive)"
    echo "  test-login          Test login for a user"
    echo "  user-info <user>    Show detailed info for a user"
    echo ""
    echo "Examples:"
    echo "  $0 list-users"
    echo "  $0 user-info developer"
    echo "  $0 create-user"
}

list_users() {
    print_info "Fetching user list..."
    kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import User
print('=' * 60)
print('AUTHENTIK USERS')
print('=' * 60)
for user in User.objects.all().order_by('username'):
    groups = [g.name for g in user.ak_groups.all()]
    status = '✅' if user.is_active else '❌'
    print(f'{status} {user.username:15} | {user.email:25} | {user.name:20} | Groups: {groups}')
print('=' * 60)
print(f'Total users: {User.objects.count()}')
"
}

list_groups() {
    print_info "Fetching group list..."
    kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import Group
print('=' * 60)
print('AUTHENTIK GROUPS')
print('=' * 60)
for group in Group.objects.all().order_by('name'):
    members = [u.username for u in group.user_set.all()]
    super_status = '🔐' if group.is_superuser else '👤'
    print(f'{super_status} {group.name:15} | Members ({len(members)}): {members}')
print('=' * 60)
print(f'Total groups: {Group.objects.count()}')
"
}

user_info() {
    local username="$1"
    if [ -z "$username" ]; then
        print_error "Username required"
        echo "Usage: $0 user-info <username>"
        exit 1
    fi
    
    print_info "Fetching user info for: $username"
    kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import User
try:
    user = User.objects.get(username='$username')
    print('=' * 50)
    print(f'USER: {user.username}')
    print('=' * 50)
    print(f'Email: {user.email}')
    print(f'Name: {user.name}')
    print(f'Active: {user.is_active}')
    print(f'Superuser: {user.is_superuser}')
    print(f'Last Login: {user.last_login}')
    print(f'Date Joined: {user.date_joined}')
    
    groups = user.ak_groups.all()
    print(f'Groups ({groups.count()}):')
    for group in groups:
        print(f'  - {group.name} ({\"superuser\" if group.is_superuser else \"regular\"})')
    
    if user.attributes:
        print('Attributes:')
        for key, value in user.attributes.items():
            print(f'  - {key}: {value}')
    
    print('=' * 50)
except User.DoesNotExist:
    print(f'❌ User \"{username}\" not found')
"
}

create_user() {
    echo "=== Create New User ==="
    read -p "Username: " username
    read -p "Email: " email
    read -p "Full Name: " name
    read -p "Password: " password
    read -p "Groups (comma-separated): " groups
    
    print_info "Creating user: $username"
    kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import User, Group
from django.contrib.auth.hashers import make_password

try:
    # Create user
    user, created = User.objects.get_or_create(
        username='$username',
        defaults={
            'email': '$email',
            'name': '$name',
            'password': make_password('$password'),
            'is_active': True,
            'attributes': {'created_by': 'user_helper'}
        }
    )
    
    if created:
        print(f'✅ User {user.username} created successfully')
        
        # Add to groups
        groups_list = '$groups'.split(',')
        for group_name in groups_list:
            group_name = group_name.strip()
            if group_name:
                try:
                    group = Group.objects.get(name=group_name)
                    user.ak_groups.add(group)
                    print(f'✅ Added to group: {group_name}')
                except Group.DoesNotExist:
                    print(f'⚠️  Group not found: {group_name}')
        
        user.save()
        print(f'🎉 User {user.username} ready to use!')
    else:
        print(f'ℹ️  User {user.username} already exists')
        
except Exception as e:
    print(f'❌ Error creating user: {e}')
"
}

reset_password() {
    read -p "Username: " username
    read -p "New Password: " password
    
    print_info "Resetting password for: $username"
    kubectl exec -n authentik "$WORKER_POD" -- ak shell -c "
from authentik.core.models import User
from django.contrib.auth.hashers import make_password

try:
    user = User.objects.get(username='$username')
    user.password = make_password('$password')
    user.save()
    print(f'✅ Password reset for {user.username}')
except User.DoesNotExist:
    print(f'❌ User \"{username}\" not found')
"
}

# Main command handler
case "${1:-}" in
    "list-users")
        list_users
        ;;
    "list-groups")
        list_groups
        ;;
    "user-info")
        user_info "$2"
        ;;
    "create-user")
        create_user
        ;;
    "reset-password")
        reset_password
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
