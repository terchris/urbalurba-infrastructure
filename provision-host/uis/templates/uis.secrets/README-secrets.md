# Secrets Templates

Templates for user secrets. These are copied to the user's `.uis.secrets/` folder when needed.

## Directory Structure

| Directory | Purpose | When Created |
|-----------|---------|--------------|
| `cloud-accounts/` | Cloud provider credentials (Azure, GCP, AWS) | When user adds a managed or cloud-vm host |
| `service-keys/` | External service API keys (Tailscale, Cloudflare, OpenAI) | When user adds host requiring these services |
| `network/` | Network credentials (WiFi) | When user adds physical device (Raspberry Pi) |

## Usage

Templates are copied by `./uis host add <template>` command based on what the host type requires.

Users edit the copied files in their `.uis.secrets/` folder with their actual credentials.

## File Naming

- Templates: `<name>.env.template`
- User files: `<name>.env` (copied from template)

## Security

- Templates contain empty placeholder values
- User files contain actual secrets
- User's `.uis.secrets/` is gitignored
