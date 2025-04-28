# Kubernetes Secrets Configuration

This document describes all the variables that need to be configured in the Kubernetes secrets file (`topsecret/kubernetes/kubernetes-secrets.yml`).

We have put all secrets for all systems that you can use in your Kubernetes cluster into one file. There are many systems and unless you are going to use a system you dont need to set the secrets for that system.
You can leave the values as they are for the initial test, to just see that it works. Then when you are ready to use the system you can change the values to your own.

## Database Credentials

### PostgreSQL
- `PGPASSWORD`: The superuser password for PostgreSQL
  - Default: `SecretPassword1`
  - Used for: Database administration and initial setup
- `PGHOST`: Database server hostname
  - Default: `postgresql`
  - Used for: Database connection

### pgAdmin
- `PGADMIN_DEFAULT_EMAIL`: Email address for the pgAdmin administrator
  - Default: `admin@example.com`
  - Used for: pgAdmin web interface login
- `PGADMIN_DEFAULT_PASSWORD`: Password for the pgAdmin administrator
  - Default: `SecretPassword1`
  - Used for: pgAdmin web interface login

## Redis
- `REDIS_HOST`: Redis server hostname
  - Default: `redis`
  - Used for: Redis connection
- `REDIS_PORT`: Redis server port
  - Default: `6379`
  - Used for: Redis connection
- `REDIS_PASSWORD`: Password for Redis authentication
  - Default: `SecretPassword1`
  - Used for: Securing Redis connections

### Redis Commander
- `redis-commander-username`: Username for Redis Commander web UI
  - Default: `admin@example.com`
  - Used for: Redis Commander web interface login
- `redis-commander-password`: Password for Redis Commander web UI
  - Default: `SecretPassword1`
  - Used for: Redis Commander web interface login

## Grafana
- `grafana-admin-user`: Email address for the Grafana administrator
  - Default: `admin@example.com`
  - Used for: Grafana web interface login
- `grafana-admin-password`: Password for the Grafana administrator
  - Default: `SecretPassword1`
  - Used for: Grafana web interface login

## Tailscale Configuration

Tailscale is used for secure networking. You need to create these keys at [Tailscale Admin Console](https://login.tailscale.com/admin/settings/keys).

- `TAILSCALE_SECRET`: Tailscale auth key
  - Format: `tskey-auth-XXXXX`
  - Used for: Authenticating new nodes to your Tailscale network
- `TAILSCALE_ACL_KEY`: Tailscale API key
  - Format: `tskey-api-XXXXX`
  - Used for: Managing Tailscale ACLs programmatically
- `TAILSCALE_TAILNET`: Your Tailscale tailnet name
  - Format: `your-github-id.github`
  - Used for: Identifying your Tailscale network
- `TAILSCALE_DOMAIN`: Your Tailscale domain name
  - Format: `some-name.ts.net`
  - Used for: DNS configuration in Tailscale
- `TAILSCALE_CLUSTER_HOSTNAME`: Nginx webserver hostname
  - Default: `www`
  - Used for: Web server configuration
- `TAILSCALE_CLIENTID`: Tailscale client ID
  - Used for: OAuth authentication
- `TAILSCALE_CLIENTSECRET`: Tailscale client secret
  - Format: `tskey-client-XXXXX`
  - Used for: OAuth authentication

## Cloudflare Configuration

Cloudflare is used for DNS management and tunneling. You need to create an API token at [Cloudflare API Tokens](https://dash.cloudflare.com/profile/api-tokens).

### Test Environment
- `CLOUDFLARE_DNS_TOKEN`: Cloudflare API token
  - Format: `XXXXX`
  - Used for: Managing DNS records and tunnels
- `CLOUDFLARE_TEST_TUNNELNAME`: Test tunnel name
  - Default: `nerdmeet-test`
  - Used for: Test environment tunnel
- `CLOUDFLARE_TEST_DOMAINNAME`: Test domain name
  - Default: `nerdmeet.org`
  - Used for: Test environment domain
- `CLOUDFLARE_TEST_SUBDOMAINS`: Test subdomains
  - Default: `www-test, jalla-test`
  - Used for: Test environment subdomains

### Production Environment
- `CLOUDFLARE_PROD_TUNNELNAME`: Production tunnel name
  - Default: `nerdmeet-prod`
  - Used for: Production environment tunnel
- `CLOUDFLARE_PROD_DOMAINNAME`: Production domain name
  - Default: `nerdmeet.org`
  - Used for: Production environment domain
- `CLOUDFLARE_PROD_SUBDOMAINS`: Production subdomains
  - Default: `www,jalla`
  - Used for: Production environment subdomains

## Elasticsearch
- `ELASTICSEARCH_PASSWORD`: Elasticsearch password
  - Default: `SecretPassword1`
  - Used for: Elasticsearch authentication

## Virtual Machine Configuration
- `UBUNTU_VM_USER`: Admin username for Ubuntu VM
  - Default: `theadminusername`
  - Used for: VM access
- `UBUNTU_VM_USER_PASSWORD`: Admin password for Ubuntu VM
  - Default: `SecretPassword1`
  - Used for: VM access

## Raspberry Pi Configuration
- `WIFI_SSID`: WiFi network name
  - Default: `jalla`
  - Used for: Raspberry Pi WiFi connection
- `WIFI_PASSWORD`: WiFi password
  - Default: `SecretPassword1`
  - Used for: Raspberry Pi WiFi connection

## MongoDB Configuration
- `MONGODB_ROOT_USER`: MongoDB root username
  - Default: `root`
  - Used for: MongoDB administration
- `MONGODB_ROOT_PASSWORD`: MongoDB root password
  - Default: `SecretPassword1`
  - Used for: MongoDB administration
- `GRAVITEE_MONGODB_DATABASE_NAME`: Gravitee database name
  - Default: `graviteedb`
  - Used for: Gravitee database
- `GRAVITEE_MONGODB_DATABASE_USER`: Gravitee database user
  - Default: `gravitee_user`
  - Used for: Gravitee database access
- `GRAVITEE_MONGODB_DATABASE_PASSWORD`: Gravitee database password
  - Default: `SecretPassword1`
  - Used for: Gravitee database access

## Gravitee.io Configuration
- `GRAVITEE_ADMIN_EMAIL`: Gravitee admin email
  - Default: `admin@example.com`
  - Used for: Gravitee admin access
- `GRAVITEE_ADMIN_PASSWORD`: Gravitee admin password
  - Default: `SecretPassword1`
  - Used for: Gravitee admin access
- `GRAVITEE_TEST_CLOUDFLARE_DOMAIN`: Test domain reference
  - Default: `CLOUDFLARE_TEST_DOMAINNAME`
  - Used for: Test environment domain
- `GRAVITEE_TEST_CLOUDFLARE_TUNNELNAME`: Test tunnel reference
  - Default: `CLOUDFLARE_TEST_TUNNELNAME`
  - Used for: Test environment tunnel
- `GRAVITEE_TEST_GATEWAY_SUBDOMAIN`: Gateway subdomain
  - Default: `gateway-test`
  - Used for: API gateway access
- `GRAVITEE_TEST_MANAGEMENT_API_SUBDOMAIN`: Management API subdomain
  - Default: `management-api-test`
  - Used for: Management API access
- `GRAVITEE_TEST_DEV_PORTAL_SUBDOMAIN`: Developer portal subdomain
  - Default: `portal-test`
  - Used for: Developer portal access
- `GRAVITEE_TEST_MANAGEMENT_CONSOLE_SUBDOMAIN`: Management console subdomain
  - Default: `management-test`
  - Used for: Management console access
- `GRAVITEE_TEST_DEV_PORTAL_API_SUBDOMAIN`: Developer portal API subdomain
  - Default: `portal-api-test`
  - Used for: Developer portal API access
- `GRAVITEE_ENCRYPTION_KEY`: Encryption key
  - Default: `EncryptionKeySecretPassword1`
  - Used for: Data encryption

## GitHub Configuration
- `GITHUB_ACCESS_TOKEN`: GitHub Personal Access Token
  - Format: `ghp_XXXXX`
  - Used for: Container registry authentication
- `YOUR_GITHUB_USERNAME`: GitHub username
  - Format: `your-github-username`
  - Used for: Container registry authentication

## Urbalurba Database Configuration
- `URBALURBA_DATABASE_PASSWORD`: Database password
  - Used for: Database access
- `URBALURBA_DATABASE_USER`: Database username
  - Used for: Database access
- `URBALURBA_DATABASE_NAME`: Database name
  - Used for: Database identification

## Strapi Configuration
- `APP_KEYS`: Application keys
  - Used for: Strapi application security
- `API_TOKEN_SALT`: API token salt
  - Used for: API token generation
- `ADMIN_JWT_SECRET`: Admin JWT secret
  - Used for: Admin authentication
- `TRANSFER_TOKEN_SALT`: Transfer token salt
  - Used for: Data transfer security
- `JWT_SECRET`: JWT secret
  - Used for: Authentication
- `URBALURBA_ADMIN_EMAIL`: Admin email
  - Used for: Admin access
- `URBALURBA_ADMIN_PASSWORD`: Admin password
  - Used for: Admin access

## AI Namespace Configuration
- `OPENWEBUI_QDRANT_API_KEY`: Qdrant API key
  - Default: `SecretPassword1-key1234567890`
  - Used for: Vector database access
- `OPENWEBUI_OPENAI_API_KEY`: OpenAI API key
  - Default: `sk-SecretPassword1`
  - Used for: OpenAI integration
- `AZURE_API_KEY`: Azure API key
  - Default: `azure-key-placeholder`
  - Used for: Azure integration
- `AZURE_API_BASE`: Azure API base URL
  - Default: `https://your-endpoint.openai.azure.com`
  - Used for: Azure integration
- `OPENAI_API_KEY`: OpenAI API key
  - Default: `openai-key-placeholder`
  - Used for: OpenAI integration
- `ANTHROPIC_API_KEY`: Anthropic API key
  - Default: `anthropic-key-placeholder`
  - Used for: Anthropic integration
- `LITELLM_PROXY_MASTER_KEY`: LiteLLM proxy master key
  - Default: `sk-SecretPassword1`
  - Used for: LiteLLM integration

## ArgoCD Configuration
- `admin.password`: Admin password (bcrypt hashed)
  - Used for: ArgoCD admin access
- `admin.passwordMtime`: Password modification time
  - Format: `YYYY-MM-DDTHH:MM:SSZ`
  - Used for: Password management

## Creating the Secrets File

You have two options to create the secrets file:

1. **Manual Creation**:
   ```bash
   cp kubernetes/kubernetes-secrets-template.yml kubernetes/kubernetes-secrets.yml
   # Then edit the file with your values
   ```

2. **Using the Script**:
   ```bash
   ./create-kubernetes-secrets.sh new
   ```
   This will guide you through setting each value interactively.

## Security Best Practices

- Use strong, unique passwords for each service
- Never commit the secrets file to version control
- Rotate secrets regularly
- Use the minimum required permissions for API tokens
- Store backup copies of the secrets file securely
- Generate random strings for encryption keys and salts
- Use different passwords for different environments (test/prod)
- Keep API keys and tokens secure and rotate them regularly 