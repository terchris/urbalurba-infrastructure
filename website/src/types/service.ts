/**
 * Service type for UIS infrastructure services.
 * Maps to services.json structure (JSON-LD SoftwareApplication).
 */
export type Service = {
  /** Unique identifier (lowercase, hyphenated) */
  identifier: string;
  /** Display name */
  name: string;
  /** Brief description (1-2 sentences) */
  description: string;
  /** Reference to category codeValue (e.g., "AI", "OBSERVABILITY") */
  applicationCategory: string;
  /** Keywords for search */
  tags: string[];
  /** One-line summary for cards */
  abstract: string;
  /** Logo filename (SVG or PNG) in static/img/services/ */
  logo: string;
  /** Official project website */
  url: string;
  /** Detailed description */
  summary: string;
  /** Kubernetes manifest filename */
  manifest: string;
  /** Path to docs within site */
  docs: string;
  /** Related service IDs (informational) */
  related: string[];
  /** Hard dependencies - service IDs that must be installed first */
  requires: string[];
};

/**
 * Props for ServiceCard component
 */
export type ServiceCardProps = {
  service: Service;
  showTags?: boolean;
};

/**
 * Props for ServiceGrid component
 */
export type ServiceGridProps = {
  /** Filter by category ID */
  category?: string;
  /** Limit number of items displayed */
  limit?: number;
  /** Show "View All" button when limited */
  showViewAll?: boolean;
  /** Show tags in cards */
  showTags?: boolean;
  /** Section title */
  title?: string;
  /** Fixed column count (responsive if not set) */
  columns?: 2 | 3 | 4;
};
