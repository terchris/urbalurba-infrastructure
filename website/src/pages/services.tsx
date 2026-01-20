/**
 * Services page - displays all UIS services organized by category.
 */
import React from 'react';
import Layout from '@theme/Layout';
import CategoryGrid from '../components/CategoryGrid';
import StackGrid from '../components/StackGrid';
import ServiceGrid from '../components/ServiceGrid';
import styles from './services.module.css';

export default function ServicesPage(): React.JSX.Element {
  return (
    <Layout
      title="Services"
      description="Browse all Urbalurba Infrastructure Stack services by category"
    >
      <main className={styles.servicesPage}>
        <header className={styles.header}>
          <h1 className={styles.title}>Services</h1>
          <p className={styles.subtitle}>
            Explore the complete catalog of infrastructure services available in
            the Urbalurba Infrastructure Stack. Deploy a full datacenter on your
            laptop.
          </p>
        </header>

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
      </main>
    </Layout>
  );
}
