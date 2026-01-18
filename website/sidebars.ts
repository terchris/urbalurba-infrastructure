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
        description: 'Service packages available in the infrastructure stack.',
      },
      items: [
        {
          type: 'category',
          label: 'AI & Machine Learning',
          link: {
            type: 'doc',
            id: 'packages/ai/index',
          },
          items: [
            'packages/ai/litellm',
            'packages/ai/litellm-client-keys',
            'packages/ai/openwebui-model-access',
            'packages/ai/environment-management',
          ],
        },
        {
          type: 'category',
          label: 'Authentication',
          link: {
            type: 'doc',
            id: 'packages/authentication/index',
          },
          items: [
            'packages/authentication/auth10',
            'packages/authentication/developer-guide',
            'packages/authentication/blueprints-syntax',
            'packages/authentication/technical-implementation',
            'packages/authentication/test-users',
          ],
        },
        {
          type: 'category',
          label: 'Core Services',
          link: {
            type: 'doc',
            id: 'packages/core/index',
          },
          items: [
            'packages/core/nginx',
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
          ],
        },
        {
          type: 'category',
          label: 'Data Science',
          link: {
            type: 'doc',
            id: 'packages/datascience/index',
          },
          items: [
            'packages/datascience/jupyterhub',
            'packages/datascience/spark',
            'packages/datascience/unitycatalog',
          ],
        },
        {
          type: 'category',
          label: 'Development',
          link: {
            type: 'doc',
            id: 'packages/development/index',
          },
          items: [
            'packages/development/argocd',
            'packages/development/templates',
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
            'packages/management/pgadmin',
            'packages/management/rabbitmq',
            'packages/management/redisinsight',
          ],
        },
        {
          type: 'category',
          label: 'Monitoring',
          link: {
            type: 'doc',
            id: 'packages/monitoring/index',
          },
          items: [
            'packages/monitoring/prometheus',
            'packages/monitoring/grafana',
            'packages/monitoring/loki',
            'packages/monitoring/tempo',
            'packages/monitoring/otel',
            'packages/monitoring/sovdev-logger',
          ],
        },
        {
          type: 'category',
          label: 'Message Queues',
          link: {
            type: 'doc',
            id: 'packages/queues/index',
          },
          items: [
            'packages/queues/rabbitmq',
            'packages/queues/redis',
          ],
        },
        {
          type: 'category',
          label: 'Search',
          link: {
            type: 'doc',
            id: 'packages/search/index',
          },
          items: [
            'packages/search/elasticsearch',
          ],
        },
      ],
    },
    {
      type: 'category',
      label: 'Networking',
      link: {
        type: 'doc',
        id: 'networking/index',
      },
      items: [
        'networking/tailscale-setup',
        'networking/tailscale-network-isolation',
        'networking/tailscale-internal-ingress',
        'networking/cloudflare-setup',
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
        'reference/documentation-index',
        'reference/manifests',
        'reference/secrets-management',
        'reference/troubleshooting',
      ],
    },
  ],
};

export default sidebars;
