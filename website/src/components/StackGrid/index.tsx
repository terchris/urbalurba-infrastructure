/**
 * StackGrid component - displays all stacks in a grid.
 */
import React from 'react';
import type { StackGridProps } from '../../types/stack';
import { getStacks } from '../../utils/data';
import StackCard from '../StackCard';
import styles from './styles.module.css';

export default function StackGrid({ title }: StackGridProps): React.JSX.Element {
  const stacks = getStacks();

  return (
    <section className={styles.section}>
      {title && <h2 className={styles.title}>{title}</h2>}
      <div className={styles.grid}>
        {stacks.map((stack) => (
          <StackCard key={stack.identifier} stack={stack} />
        ))}
      </div>
    </section>
  );
}
