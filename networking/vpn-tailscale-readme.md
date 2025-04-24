# Tailscale VPN Howto

This guide explains how to set up Tailscale for connecting your infrastructure, specifically focusing on how the provision host connects to MicroK8s VMs.

## Getting Started

To use Tailscale, you need to create an account at [tailscale.com](https://tailscale.com/). After registration, you'll set up a network (tailnet) where you'll add your devices.

## Authentication Keys and Tagging

Tailscale uses a combination of authentication keys and tags to manage access. Here's how they work together:

### Generate an Auth Key

1. In the Tailscale admin console, navigate to "Settings" > "Keys" (URL: login.tailscale.com/admin/settings/keys)
2. Click on "Generate auth key"
3. Add a description (e.g., "infrastructure-auth-key") to identify the purpose of this key
4. Enable the "Reusable" toggle to allow multiple machines to authenticate with this key
5. Set the expiration period (maximum is 90 days)
6. Under "Device Settings":
   - **DO NOT enable "Ephemeral"** - this setting would cause machines to be removed from your network if they go offline, which would break your infrastructure
   - **Enable "Tags"** - this is critical for your setup to work correctly
   - The Tags toggle allows machines to request specific tags when they join
7. Click "Generate key"

The generated key will look like this:
```
tskey-auth-ktyTufs...and---so-on
```

### Generate an API/ACL Key

You'll also need an API key to manage access control:

1. In the admin console, navigate to "Settings" > "Keys"
2. Click on "Generate access token..." 
3. This key is used for programmatic control of your Tailscale network

## Setting Up Tag Ownership

In the Tailscale ACL Editor (https://login.tailscale.com/admin/acl), define which tags you'll use and who owns them:

```json
"tagOwners": {
  "tag:provision-host": ["yourusername@github"],
  "tag:microk8s": ["yourusername@github"]
}
```

Replace `yourusername@github` with your actual GitHub username.

## Access Control Configuration

Configure your ACL to allow SSH access based on tags:

```json
{
  "tagOwners": {
    "tag:provision-host": ["yourusername@github"],
    "tag:microk8s": ["yourusername@github"]
  },
  "acls": [
    // Allow all hosts to communicate freely with each other
    {"action": "accept", "src": ["*"], "dst": ["*:*"]}
  ],
  "ssh": [
    // Allow provision-host to SSH into microk8s clusters as the ansible user
    {
      "action": "accept",
      "src": ["tag:provision-host"],
      "dst": ["tag:microk8s"],
      "users": ["ansible"]
    },
    // Allow all users to SSH into their own devices in check mode
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["autogroup:self"],
      "users": ["autogroup:nonroot", "root"]
    },
    // Allow all users to SSH into any device
    {
      "action": "check",
      "src": ["autogroup:member"],
      "dst": ["*"],
      "users": ["autogroup:nonroot", "root"]
    }
  ]
}
```

This configuration:
- Allows all hosts to communicate freely
- Permits SSH access from provision-host to microk8s nodes as the ansible user
- Allows web interface SSH access to devices

## Kubernetes Secrets Configuration

Add your Tailscale keys to your kubernetes-secrets.yml file, which is stored locally at:
```
topsecret/kubernetes/kubernetes-secrets.yml
```

This file is never committed to the repository for security reasons. Add the following entries:

```yaml
# Tailscale network configuration - REMEMBER these keys expire in max 90 days
  TAILSCALE_SECRET: tskey-auth-ktyTufs...and---so-on
# the TAILSCALE_SECRET is used when adding hosts to the network
  TAILSCALE_ACL_KEY: tskey-api-kda.... and so on
# the TAILSCALE_ACL_KEY is used by the provision-host to manage access control on the network
  TAILSCALE_TAILNET: yourusername.github
# the TAILSCALE_TAILNET is the name of your tailscale network - typically your GitHub ID
```

## Updating Secrets in local Kubernetes cluster

After updating the kubernetes-secrets.yml file, you need to push these secrets to your Kubernetes cluster. Use the appropriate script from the topsecret folder:

- For Kubernetes in MicroK8s on local multipass VM: `topsecret/update-kubernetes-secrets.sh`
- For Kubernetes in Rancher Desktop: `topsecret/update-kubernetes-secrets-rancher.sh`

These scripts apply the secrets to your local Kubernetes cluster.

## Automated Setup with Cloud-Init

Your VMs are automatically configured via cloud-init with the correct Tailscale configuration and user accounts. The relevant sections from your cloud-init file:

```yaml
# User configuration
users:
  - name: ansible
    groups: [sudo]
    shell: /bin/bash
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    ssh_authorized_keys:
      - *ssh_key
    create_home: true

# Tailscale installation and setup
- ['sh', '-c', 'curl -fsSL https://tailscale.com/install.sh | sh']
- ['sh', '-c', "echo 'net.ipv4.ip_forward = 1' | tee -a /etc/sysctl.d/99-tailscale.conf && echo 'net.ipv6.conf.all.forwarding = 1' | tee -a /etc/sysctl.d/99-tailscale.conf && sysctl -p /etc/sysctl.d/99-tailscale.conf"]
- ['systemctl', 'enable', 'tailscaled']
- ['tailscale', 'up', '--authkey', *tailscale_key, '--hostname', *hostname, '--accept-routes', '--accept-dns', '--advertise-tags=tag:microk8s']
- ['tailscale', 'set', '--auto-update', '--ssh', '--accept-routes', '--accept-dns']
```

Note the important elements:
1. The `ansible` user is created with sudo privileges and your SSH key
2. Tailscale is configured with `--advertise-tags=tag:microk8s` which automatically assigns the microk8s tag to your VMs when they join the network
3. SSH access via Tailscale is enabled with `--ssh`

## Provision Host Setup

Similarly, your provision host needs to be configured with the `tag:provision-host` tag:

```bash
sudo tailscale up --authkey=tskey-auth-ktyTufs...and---so-on --hostname=provision-host --accept-routes --accept-dns --advertise-tags=tag:provision-host
sudo tailscale set --auto-update --ssh --accept-routes --accept-dns
```

This ensures that the provision host can connect to your microk8s VMs based on the ACL rules.

## User Accounts Setup

Both the provision host and the MicroK8s VMs are set up with a user named `ansible`:

1. The provision host has an `ansible` user with SSH access
2. All MicroK8s VMs have an `ansible` user configured with your SSH key
3. The ACL is specifically designed to allow SSH connections as the `ansible` user

This consistent user account setup is critical for the automation to work properly, as it ensures that:
- The provision host can SSH into all VMs using the same user credentials
- The ansible automation can run with consistent permissions across all machines
- The ACL rules can target a specific user for access control

## GitHub Integration with Tailscale

The documentation references GitHub IDs in several places because the Tailscale account was created by logging in with a GitHub account. This affects:

1. **TAILSCALE_TAILNET**: This is set to `yourusername.github` because the Tailscale network is identified by your GitHub username
2. **Tag ownership**: Tag owners are specified as `yourusername@github` in the ACL configuration
3. **ACL management**: When editing ACLs, you'll use your GitHub identity for authentication

This GitHub integration simplifies user management if your team already uses GitHub for other purposes.

## How It All Works Together

1. You create a reusable auth key in Tailscale with Tags enabled
2. You set up your ACL to control access based on tags
3. When VMs join:
   - MicroK8s VMs advertise the `tag:microk8s` tag
   - The provision host advertises the `tag:provision-host` tag
4. The ACL allows SSH connections from `tag:provision-host` to `tag:microk8s` as the ansible user
5. The ansible user on the MicroK8s VMs is pre-configured with your SSH key

This "tag-based" approach allows you to use a single auth key for all machines while still maintaining proper access control.

## Key Expiration and Renewal

Tailscale auth keys expire after a maximum of 90 days. When renewing:

1. Generate new keys in the Tailscale admin console
2. Update your kubernetes-secrets.yml file with the new keys
3. Run the update-kubernetes-secrets.sh script
4. If needed, re-authenticate your devices with the new key
