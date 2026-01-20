import React from 'react';
import clsx from 'clsx';
import Link from '@docusaurus/Link';
import styles from './styles.module.css';

type FeatureItem = {
  title: string;
  description: string;
  link: string;
  icon: string;
};

const FeatureList: FeatureItem[] = [
  {
    title: 'AI & Machine Learning',
    description: 'OpenWebUI, LiteLLM, and Ollama integration for local AI development with unified API access.',
    link: '/docs/packages/ai',
    icon: '🤖',
  },
  {
    title: 'Databases',
    description: 'PostgreSQL, MySQL, MongoDB, Redis, and Qdrant - all pre-configured and ready to use.',
    link: '/docs/packages/databases',
    icon: '🗄️',
  },
  {
    title: 'Observability',
    description: 'Grafana, Prometheus, Loki, and Tempo for comprehensive monitoring, logging, and tracing.',
    link: '/docs/packages/monitoring',
    icon: '📊',
  },
  {
    title: 'Authentication',
    description: 'Authentik SSO with OIDC/OAuth2 support for secure, centralized identity management.',
    link: '/docs/packages/authentication',
    icon: '🔐',
  },
  {
    title: 'Data Science',
    description: 'Apache Spark, JupyterHub, and Unity Catalog for scalable data processing and analysis.',
    link: '/docs/packages/datascience',
    icon: '🔬',
  },
  {
    title: 'Multi-Platform',
    description: 'Deploy on your laptop with Rancher Desktop, Azure AKS, or Raspberry Pi clusters.',
    link: '/docs/hosts',
    icon: '🌐',
  },
];

function Feature({ title, description, link, icon }: FeatureItem) {
  return (
    <div className={clsx('col col--4')}>
      <Link to={link} className={styles.featureLink}>
        <div className={styles.featureCard}>
          <div className={styles.featureIcon}>{icon}</div>
          <h3 className={styles.featureTitle}>{title}</h3>
          <p className={styles.featureDescription}>{description}</p>
        </div>
      </Link>
    </div>
  );
}

export default function HomepageFeatures(): React.JSX.Element {
  return (
    <section className={styles.features}>
      <div className="container">
        <div className={styles.sectionHeader}>
          <h2>Service Categories</h2>
          <p>Everything you need for a complete development infrastructure</p>
        </div>
        <div className="row">
          {FeatureList.map((props, idx) => (
            <Feature key={idx} {...props} />
          ))}
        </div>
      </div>
    </section>
  );
}
