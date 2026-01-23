# Ubuntu Cloud-Init Templates

These templates are used to generate cloud-init configuration files for provisioning VMs and physical devices.

## Available Templates

| Template | Purpose |
|----------|---------|
| `azure-cloud-init-template.yml` | Azure VMs with MicroK8s |
| `gcp-cloud-init-template.yml` | GCP VMs with MicroK8s |
| `multipass-cloud-init-template.yml` | Local Multipass VMs |
| `raspberry-cloud-init-template.yml` | Raspberry Pi devices |
| `provision-cloud-init-template.yml` | Generic provision host |

## Variable Substitution

Templates use `URB_` prefixed variables that are replaced during generation:

| Variable | Description |
|----------|-------------|
| `URB_SSH_AUTHORIZED_KEY_VARIABLE` | SSH public key for ansible user |
| `URB_HOSTNAME_VARIABLE` | Device hostname |
| `URB_TIMEZONE_VARIABLE` | System timezone |
| `URB_TAILSCALE_SECRET_VARIABLE` | Tailscale auth key |
| `URB_WIFI_SSID_VARIABLE` | WiFi network name (Raspberry Pi) |
| `URB_WIFI_PASSWORD_VARIABLE` | WiFi password (Raspberry Pi) |

## Usage

Generated files are placed in `.uis.secrets/generated/ubuntu-cloud-init/`.

```bash
# Generate cloud-init for a host
./uis host generate my-raspberry-pi

# Output: .uis.secrets/generated/ubuntu-cloud-init/my-raspberry-pi-cloud-init.yml
```

## What the Templates Configure

- Creates `ansible` user with SSH key access
- Installs MicroK8s
- Installs and configures Tailscale for network connectivity
- Sets up system PATH and permissions
- Enables essential MicroK8s addons (dns, dashboard, helm, hostpath-storage)
