/**
 * ServiceCard component - displays a single service in a card format.
 */
import React from 'react';
import Link from '@docusaurus/Link';
import useBaseUrl from '@docusaurus/useBaseUrl';
import type { ServiceCardProps } from '../../types/service';
import styles from './styles.module.css';

export default function ServiceCard({ service }: ServiceCardProps): React.JSX.Element {
  const logoUrl = useBaseUrl(`/img/services/${service.logo}`);
  // Use the docs path from services.json directly
  const servicePath = service.docs;

  return (
    <article className={styles.serviceCard}>
      <div className={styles.logoContainer}>
        <img
          src={logoUrl}
          alt={`${service.name} logo`}
          className={styles.logo}
          loading="lazy"
        />
      </div>
      <div className={styles.content}>
        <Link to={servicePath} className={styles.title}>
          {service.name}
        </Link>
        <p className={styles.abstract}>{service.abstract}</p>
        {service.tags.length > 0 && (
          <div className={styles.tags}>
            {service.tags.slice(0, 3).map((tag) => (
              <span key={tag} className={styles.tag}>
                {tag}
              </span>
            ))}
          </div>
        )}
      </div>
    </article>
  );
}
