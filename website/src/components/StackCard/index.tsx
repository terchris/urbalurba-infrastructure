/**
 * StackCard component - displays a stack with flow diagram preview.
 */
import React from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import type { StackCardProps } from '../../types/stack';
import ServiceFlowDiagram from '../ServiceFlowDiagram';
import styles from './styles.module.css';

export default function StackCard({ stack }: StackCardProps): React.JSX.Element {
  const logoUrl = useBaseUrl(`/img/stacks/${stack.logo}`);

  return (
    <article className={styles.stackCard}>
      <div className={styles.header}>
        <div className={styles.logoContainer}>
          <img
            src={logoUrl}
            alt={`${stack.name} logo`}
            className={styles.logo}
            loading="lazy"
          />
        </div>
        <div className={styles.headerContent}>
          <h3 className={styles.title}>{stack.name}</h3>
          <p className={styles.description}>{stack.description}</p>
        </div>
      </div>
      <div className={styles.flowSection}>
        <ServiceFlowDiagram components={stack.components} showNames={false} />
        <span className={styles.componentCount}>
          {stack.components.length} {stack.components.length === 1 ? 'service' : 'services'}
        </span>
      </div>
    </article>
  );
}
