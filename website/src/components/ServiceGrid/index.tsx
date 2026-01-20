/**
 * ServiceGrid component - displays services grouped by category.
 */
import React from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import type { ServiceGridProps } from '../../types/service';
import type { Category } from '../../types/category';
import { getCategories, getServicesByCategory } from '../../utils/data';
import { getCategoryAnchor } from '../../utils/paths';
import ServiceCard from '../ServiceCard';
import styles from './styles.module.css';

export default function ServiceGrid({ title }: ServiceGridProps): React.JSX.Element {
  const categories = getCategories();

  return (
    <div>
      {title && <h2>{title}</h2>}
      {categories.map((category) => (
        <CategorySection key={category.codeValue} category={category} />
      ))}
    </div>
  );
}

function CategorySection({ category }: { category: Category }): React.JSX.Element | null {
  const services = getServicesByCategory(category.codeValue);
  const logoUrl = useBaseUrl(`/img/categories/${category.logo}`);

  if (services.length === 0) {
    return null;
  }

  return (
    <section
      id={getCategoryAnchor(category.codeValue)}
      className={styles.section}
    >
      <header className={styles.sectionHeader}>
        <img
          src={logoUrl}
          alt={`${category.name} icon`}
          className={styles.sectionLogo}
        />
        <h3 className={styles.sectionTitle}>{category.name}</h3>
        <span className={styles.serviceCount}>
          {services.length} {services.length === 1 ? 'service' : 'services'}
        </span>
      </header>
      <div className={styles.grid}>
        {services.map((service) => (
          <ServiceCard key={service.identifier} service={service} />
        ))}
      </div>
    </section>
  );
}
