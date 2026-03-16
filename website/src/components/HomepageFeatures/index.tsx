import React from 'react';
import CategoryGrid from '../CategoryGrid';
import StackGrid from '../StackGrid';
import ServiceGrid from '../ServiceGrid';
import styles from './styles.module.css';

export default function HomepageFeatures(): React.JSX.Element {
  return (
    <div className={styles.servicesShowcase}>
      <section className={styles.section}>
        <h2 className={styles.sectionTitle}>Categories</h2>
        <CategoryGrid excludeEmpty />
      </section>

      <section className={styles.section}>
        <h2 className={styles.sectionTitle}>Pre-configured Stacks</h2>
        <StackGrid />
      </section>

      <section className={styles.section}>
        <h2 className={styles.sectionTitle}>All Services</h2>
        <ServiceGrid />
      </section>
    </div>
  );
}
