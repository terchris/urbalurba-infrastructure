/**
 * URL path utilities for UIS services and categories.
 */

/**
 * Maps category ID to folder name for docs URL paths.
 */
export function getCategoryFolder(category: string): string {
  const mapping: Record<string, string> = {
    AI: 'ai',
    AUTHENTICATION: 'authentication',
    DATABASES: 'databases',
    MONITORING: 'monitoring',
    QUEUES: 'queues',
    SEARCH: 'search',
    DATASCIENCE: 'datascience',
    CORE: 'core',
    MANAGEMENT: 'management',
    DEVELOPMENT: 'development',
  };
  return mapping[category] || category.toLowerCase();
}

/**
 * Generates anchor ID from category name.
 * Used for in-page navigation on /services page.
 */
export function getCategoryAnchor(category: string): string {
  return category.toLowerCase();
}

/**
 * Generates the full path to a service's detail page.
 * Links to docs page if available, otherwise returns undefined.
 */
export function getServicePath(serviceId: string, category: string): string {
  const folder = getCategoryFolder(category);
  return `/docs/packages/${folder}/${serviceId}`;
}

/**
 * Generates URL-safe anchor/slug from text.
 * Matches Docusaurus's default anchor generation.
 */
export function generateAnchor(text: string): string {
  return text
    .toLowerCase()
    .replace(/\s+/g, '-')
    .replace(/[^a-z0-9-]/g, '')
    .replace(/^-+|-+$/g, '');
}

/**
 * Generates path to category section on services page.
 */
export function getCategoryPath(categoryId: string): string {
  return `/services#${getCategoryAnchor(categoryId)}`;
}
