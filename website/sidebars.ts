import type { SidebarsConfig } from '@docusaurus/plugin-content-docs';

const sidebars: SidebarsConfig = {
  tutorialSidebar: [
    'index',
    'about',
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
            'packages/analytics/openmetadata',
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
            'packages/integration/enonic',
            'packages/integration/rabbitmq',
            'packages/integration/gravitee',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Developing and Deploying',
      link: {
        type: 'generated-index',
        description: 'Create projects from templates and deploy to the cluster with ArgoCD.',
      },
      items: [
        'developing/dev-templates',
        'developing/template-catalog',
        'developing/argocd-pipeline',
        'developing/argocd-commands',
        'developing/argocd-dashboard',
      ],
    },
    {
      type: 'category',
      label: 'Advanced',
      link: {
        type: 'generated-index',
        description: 'Host configuration, platform setup, and infrastructure details.',
      },
      items: [
        {
          type: 'category',
          label: 'Hosts & Platforms',
          link: {
            type: 'doc',
            id: 'advanced/hosts/index',
          },
          items: [
            'advanced/hosts/rancher-kubernetes',
            'advanced/hosts/azure-aks',
            'advanced/hosts/azure-microk8s',
            'advanced/hosts/multipass-microk8s',
            'advanced/hosts/raspberry-microk8s',
            {
              type: 'category',
              label: 'Cloud Init',
              items: [
                'advanced/hosts/cloud-init/index',
                'advanced/hosts/cloud-init/secrets',
              ],
            },
          ],
        },
        {
          type: 'category',
          label: 'Provision Host',
          link: {
            type: 'doc',
            id: 'advanced/provision-host/index',
          },
          items: [
            'advanced/provision-host/rancher',
          ],
        },
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
        'reference/factory-reset',
        'reference/documentation-index',
        'reference/troubleshooting',
      ],
    },
    {
      type: 'category',
      label: 'Contributors',
      link: {
        type: 'doc',
        id: 'contributors/index',
      },
      items: [
        {
          type: 'category',
          label: 'Guides',
          link: {
            type: 'doc',
            id: 'contributors/guides/index',
          },
          items: [
            'contributors/guides/adding-a-service',
          ],
        },
        {
          type: 'category',
          label: 'Rules & Standards',
          link: {
            type: 'doc',
            id: 'contributors/rules/index',
          },
          items: [
            'contributors/rules/kubernetes-deployment',
            'contributors/rules/ingress-traefik',
            'contributors/rules/secrets-management',
            'contributors/rules/provisioning',
            'contributors/rules/naming-conventions',
            'contributors/rules/git-workflow',
            'contributors/rules/development-workflow',
            'contributors/rules/documentation',
          ],
        },
        {
          type: 'category',
          label: 'Architecture',
          items: [
            'contributors/architecture/deploy-system',
            'contributors/architecture/tools',
            'contributors/architecture/manifests',
            'contributors/architecture/secrets',
          ],
        },
      ],
    },
  ],
};

export default sidebars;
