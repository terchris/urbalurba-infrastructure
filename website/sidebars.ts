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
      label: 'Services',
      link: {
        type: 'generated-index',
        description: 'Services and categories available in the infrastructure stack.',
      },
      items: [
        {
          type: 'category',
          label: 'Observability',
          link: {
            type: 'doc',
            id: 'services/observability/index',
          },
          items: [
            'services/observability/prometheus',
            'services/observability/grafana',
            'services/observability/loki',
            'services/observability/tempo',
            'services/observability/otel',
            'services/observability/sovdev-logger',
          ],
        },
        {
          type: 'category',
          label: 'AI & Machine Learning',
          link: {
            type: 'doc',
            id: 'services/ai/index',
          },
          items: [
            'services/ai/openwebui',
            'services/ai/litellm',
            'services/ai/litellm-client-keys',
            'services/ai/openwebui-model-access',
            'services/ai/environment-management',
          ],
        },
        {
          type: 'category',
          label: 'Analytics',
          link: {
            type: 'doc',
            id: 'services/analytics/index',
          },
          items: [
            'services/analytics/jupyterhub',
            'services/analytics/openmetadata',
            'services/analytics/spark',
            'services/analytics/unitycatalog',
          ],
        },
        {
          type: 'category',
          label: 'Identity',
          link: {
            type: 'doc',
            id: 'services/identity/index',
          },
          items: [
            'services/identity/authentik',
            'services/identity/auth10',
            'services/identity/developer-guide',
            'services/identity/blueprints-syntax',
            'services/identity/technical-implementation',
            'services/identity/test-users',
          ],
        },
        {
          type: 'category',
          label: 'Databases',
          link: {
            type: 'doc',
            id: 'services/databases/index',
          },
          items: [
            'services/databases/postgresql',
            'services/databases/postgresql-container',
            'services/databases/mysql',
            'services/databases/mongodb',
            'services/databases/qdrant',
            'services/databases/redis',
            'services/databases/elasticsearch',
          ],
        },
        {
          type: 'category',
          label: 'Management',
          link: {
            type: 'doc',
            id: 'services/management/index',
          },
          items: [
            'services/management/argocd',
            'services/management/backstage',
            'services/management/pgadmin',
            'services/management/redisinsight',
            'services/management/nginx',
            'services/management/whoami',
          ],
        },
        {
          type: 'category',
          label: 'Applications',
          link: {
            type: 'doc',
            id: 'services/applications/index',
          },
          items: [
            'services/applications/nextcloud',
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
            'services/networking/tailscale-tunnel',
            'services/networking/cloudflare-tunnel',
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
            id: 'services/integration/index',
          },
          items: [
            'services/integration/enonic',
            'services/integration/rabbitmq',
            'services/integration/gravitee',
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
      label: 'AI Development',
      link: {
        type: 'doc',
        id: 'ai-developer/README',
      },
      items: [
        { type: 'autogenerated', dirName: 'ai-developer' },
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
