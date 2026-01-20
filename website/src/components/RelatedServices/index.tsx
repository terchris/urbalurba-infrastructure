/**
 * RelatedServices component - horizontal scrolling list of related services.
 */
import React from 'react';
import type { Service } from '../../types/service';
import ServiceCard from '../ServiceCard';
import styles from './styles.module.css';

type RelatedServicesProps = {
  services: Service[];
  title?: string;
};

export default function RelatedServices({
  services,
  title = 'Related Services',
}: RelatedServicesProps): React.JSX.Element | null {
  if (services.length === 0) {
    return null;
  }

  return (
    <section className={styles.section}>
      <h3 className={styles.title}>{title}</h3>
      <div className={styles.scrollContainer}>
        {services.map((service) => (
          <div key={service.identifier} className={styles.cardWrapper}>
            <ServiceCard service={service} />
          </div>
        ))}
      </div>
    </section>
  );
}
