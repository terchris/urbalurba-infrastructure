/**
 * ServiceFlowDiagram component - displays stack components as a flow diagram.
 * Shows services in installation order with arrows between them.
 */
import React from 'react';
import useBaseUrl from '@docusaurus/useBaseUrl';
import type { ServiceFlowDiagramProps } from '../../types/stack';
import { getServiceById } from '../../utils/data';
import styles from './styles.module.css';

export default function ServiceFlowDiagram({
  components,
  showNames = true,
}: ServiceFlowDiagramProps): React.JSX.Element {
  // Sort by position
  const sortedComponents = [...components].sort((a, b) => a.position - b.position);

  return (
    <div className={styles.flowContainer}>
      {sortedComponents.map((component, index) => {
        const service = getServiceById(component.service);
        if (!service) return null;

        return (
          <React.Fragment key={component.service}>
            <ServiceNode
              service={service}
              optional={component.optional}
              showName={showNames}
            />
            {index < sortedComponents.length - 1 && <Arrow />}
          </React.Fragment>
        );
      })}
    </div>
  );
}

type ServiceNodeProps = {
  service: { identifier: string; name: string; logo: string };
  optional?: boolean;
  showName?: boolean;
};

function ServiceNode({ service, optional, showName }: ServiceNodeProps): React.JSX.Element {
  const logoUrl = useBaseUrl(`/img/services/${service.logo}`);

  return (
    <div className={`${styles.serviceNode} ${optional ? styles.optionalNode : ''}`}>
      <img
        src={logoUrl}
        alt={`${service.name} logo`}
        className={styles.serviceLogo}
        title={service.name}
      />
      {showName && <span className={styles.serviceName}>{service.name}</span>}
    </div>
  );
}

function Arrow(): React.JSX.Element {
  return (
    <svg
      className={styles.arrow}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
    >
      <line x1="5" y1="12" x2="19" y2="12" />
      <polyline points="12 5 19 12 12 19" />
    </svg>
  );
}
