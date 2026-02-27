import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'index',
    {
      type: 'category',
      label: 'Getting Started',
      link: {
        type: 'generated-index',
        description: 'Get up and running with the Urbalurba Infrastructure Stack.',
      },
      items: [
        'getting-started/overview',
        'getting-started/installation',
        'getting-started/infrastructure',
        'getting-started/services',
        'getting-started/architecture',
      ],
    },
    {
      type: 'category',
      label: 'Hosts & Platforms',
      link: {
        type: 'doc',
        id: 'hosts/index',
      },
      items: [
        'hosts/rancher-kubernetes',
        'hosts/azure-aks',
        'hosts/azure-microk8s',
        'hosts/multipass-microk8s',
        'hosts/raspberry-microk8s',
        {
          type: 'category',
          label: 'Cloud Init',
          items: [
            'hosts/cloud-init/index',
            'hosts/cloud-init/secrets',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Packages',
      link: {
        type: 'generated-index',
        description: 'Service packages and categories available in the infrastructure stack.',
      },
      items: [
        {
          type: 'category',
          label: 'Observability',
          link: {
            type: 'doc',
            id: 'packages/observability/index',
          },
          items: [
            'packages/observability/prometheus',
            'packages/observability/grafana',
            'packages/observability/loki',
            'packages/observability/tempo',
            'packages/observability/otel',
            'packages/observability/sovdev-logger',
          ],
        },
        {
          type: 'category',
          label: 'AI & Machine Learning',
          link: {
            type: 'doc',
            id: 'packages/ai/index',
          },
          items: [
            'packages/ai/openwebui',
            'packages/ai/litellm',
            'packages/ai/litellm-client-keys',
            'packages/ai/openwebui-model-access',
            'packages/ai/environment-management',
          ],
        },
        {
          type: 'category',
          label: 'Analytics',
          link: {
            type: 'doc',
            id: 'packages/analytics/index',
          },
          items: [
            'packages/analytics/jupyterhub',
            'packages/analytics/spark',
            'packages/analytics/unitycatalog',
          ],
        },
        {
          type: 'category',
          label: 'Identity',
          link: {
            type: 'doc',
            id: 'packages/identity/index',
          },
          items: [
            'packages/identity/authentik',
            'packages/identity/auth10',
            'packages/identity/developer-guide',
            'packages/identity/blueprints-syntax',
            'packages/identity/technical-implementation',
            'packages/identity/test-users',
          ],
        },
        {
          type: 'category',
          label: 'Databases',
          link: {
            type: 'doc',
            id: 'packages/databases/index',
          },
          items: [
            'packages/databases/postgresql',
            'packages/databases/postgresql-container',
            'packages/databases/mysql',
            'packages/databases/mongodb',
            'packages/databases/qdrant',
            'packages/databases/redis',
            'packages/databases/elasticsearch',
          ],
        },
        {
          type: 'category',
          label: 'Management',
          link: {
            type: 'doc',
            id: 'packages/management/index',
          },
          items: [
            'packages/management/argocd',
            'packages/management/pgadmin',
            'packages/management/redisinsight',
            'packages/management/nginx',
            'packages/management/whoami',
            'packages/management/templates',
          ],
        },
        {
          type: 'category',
          label: 'Networking',
          link: {
            type: 'generated-index',
            description: 'VPN tunnels and network access services.',
          },
          items: [
            'packages/networking/tailscale-tunnel',
            'packages/networking/cloudflare-tunnel',
            'networking/tailscale-setup',
            'networking/tailscale-network-isolation',
            'networking/tailscale-internal-ingress',
            'networking/cloudflare-setup',
          ],
        },
        {
          type: 'category',
          label: 'Storage',
          link: {
            type: 'generated-index',
            description: 'Platform storage infrastructure.',
          },
          items: [],
        },
        {
          type: 'category',
          label: 'Integration',
          link: {
            type: 'doc',
            id: 'packages/integration/index',
          },
          items: [
            'packages/integration/rabbitmq',
            'packages/integration/gravitee',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Provision Host',
      link: {
        type: 'doc',
        id: 'provision-host/index',
      },
      items: [
        'provision-host/rancher',
        'provision-host/kubernetes',
        'provision-host/tools',
      ],
    },
    {
      type: 'category',
      label: 'Rules & Standards',
      link: {
        type: 'doc',
        id: 'rules/index',
      },
      items: [
        'rules/kubernetes-deployment',
        'rules/ingress-traefik',
        'rules/secrets-management',
        'rules/provisioning',
        'rules/naming-conventions',
        'rules/git-workflow',
        'rules/development-workflow',
        'rules/documentation',
        'rules/documentation-legacy',
      ],
    },
    {
      type: 'category',
      label: 'Reference',
      link: {
        type: 'generated-index',
        description: 'Reference documentation and troubleshooting guides.',
      },
      items: [
        'reference/uis-cli-reference',
        'reference/service-dependencies',
        'reference/documentation-index',
        'reference/manifests',
        'reference/secrets-management',
        'reference/troubleshooting',
      ],
    },
  ],
};

export default sidebars;
