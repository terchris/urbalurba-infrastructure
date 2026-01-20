/**
 * CategoryGrid component - displays all categories in a grid.
 */
import React from 'react';
import type { CategoryGridProps } from '../../types/category';
import { getCategories, getServiceCountByCategory } from '../../utils/data';
import CategoryCard from '../CategoryCard';
import styles from './styles.module.css';

export default function CategoryGrid({
  excludeEmpty = false,
  title,
}: CategoryGridProps): React.JSX.Element {
  const categories = getCategories();

  const filteredCategories = excludeEmpty
    ? categories.filter((cat) => getServiceCountByCategory(cat.codeValue) > 0)
    : categories;

  return (
    <section className={styles.section}>
      {title && <h2 className={styles.title}>{title}</h2>}
      <div className={styles.grid}>
        {filteredCategories.map((category) => (
          <CategoryCard
            key={category.codeValue}
            category={category}
            serviceCount={getServiceCountByCategory(category.codeValue)}
          />
        ))}
      </div>
    </section>
  );
}
