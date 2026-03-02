/**
 * CategoryCard component - displays a category with service count.
 */
import React from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import type { CategoryCardProps } from '../../types/category';
import { getCategoryPath } from '../../utils/paths';
import styles from './styles.module.css';

export default function CategoryCard({
  category,
  serviceCount,
}: CategoryCardProps): React.JSX.Element {
  const logoUrl = useBaseUrl(`/img/categories/${category.logo}`);
  const categoryPath = getCategoryPath(category.codeValue);

  return (
    <a href={categoryPath} className={styles.categoryCard}>
      <div className={styles.logoContainer}>
        <img
          src={logoUrl}
          alt={`${category.name} icon`}
          className={styles.logo}
          loading="lazy"
        />
      </div>
      <div className={styles.content}>
        <h3 className={styles.title}>{category.name}</h3>
        <p className={styles.abstract}>{category.abstract}</p>
        <span className={styles.serviceCount}>
          {serviceCount} {serviceCount === 1 ? 'service' : 'services'}
        </span>
      </div>
    </a>
  );
}
