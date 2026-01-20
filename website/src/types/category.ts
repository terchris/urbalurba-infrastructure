/**
 * Category type for UIS service categories.
 * Maps to categories.json structure (JSON-LD CategoryCode).
 */
export type Category = {
  /** Unique identifier (uppercase, e.g., "AI", "MONITORING") */
  codeValue: string;
  /** Display name */
  name: string;
  /** Sort order for display */
  order: number;
  /** Keywords for search */
  tags: string[];
  /** One-line summary for cards */
  abstract: string;
  /** Detailed description */
  summary: string;
  /** Logo filename (SVG) in static/img/categories/ */
  logo: string;
  /** Manifest number range (e.g., "200-229") */
  manifest_range: string;
};

/**
 * Props for CategoryCard component
 */
export type CategoryCardProps = {
  category: Category;
  serviceCount: number;
};

/**
 * Props for CategoryGrid component
 */
export type CategoryGridProps = {
  /** Exclude categories with no services */
  excludeEmpty?: boolean;
  /** Section title */
  title?: string;
};
