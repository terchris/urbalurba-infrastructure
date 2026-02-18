/**
 * Data loading utilities for UIS services, categories, and stacks.
 */

import type { Service } from '../types/service';
import type { Category } from '../types/category';
import type { Stack } from '../types/stack';

// Import JSON data
import servicesData from '../data/services.json';
import categoriesData from '../data/categories.json';
import stacksData from '../data/stacks.json';

/**
 * Get all services from services.json
 * Maps JSON field names (id, category, website) to Service type fields
 * (identifier, applicationCategory, url)
 */
export function getServices(): Service[] {
  return servicesData.services.map((s) => ({
    identifier: s.id,
    name: s.name,
    description: s.description,
    applicationCategory: s.category,
    tags: s.tags,
    abstract: s.abstract,
    logo: s.logo,
    url: s.website,
    summary: s.summary,
    manifest: '',
    docs: s.docs,
    related: [],
    requires: s.requires,
  }));
}

/**
 * Get all categories from categories.json, sorted by order
 * Maps JSON field names (id, description, icon) to Category type fields
 * (codeValue, etc.)
 */
export function getCategories(): Category[] {
  const categories: Category[] = categoriesData.categories.map((c) => ({
    codeValue: c.id,
    name: c.name,
    order: c.order,
    tags: [],
    abstract: c.description,
    summary: c.description,
    logo: '',
    manifest_range: '',
  }));
  return categories.sort((a, b) => a.order - b.order);
}

/**
 * Get all stacks from stacks.json
 */
export function getStacks(): Stack[] {
  return stacksData.itemListElement as Stack[];
}

/**
 * Get services filtered by category
 */
export function getServicesByCategory(categoryId: string): Service[] {
  return getServices().filter(
    (service) => service.applicationCategory === categoryId
  );
}

/**
 * Get a single service by ID
 */
export function getServiceById(serviceId: string): Service | undefined {
  return getServices().find((service) => service.identifier === serviceId);
}

/**
 * Get a single category by ID
 */
export function getCategoryById(categoryId: string): Category | undefined {
  return getCategories().find((category) => category.codeValue === categoryId);
}

/**
 * Get a single stack by ID
 */
export function getStackById(stackId: string): Stack | undefined {
  return getStacks().find((stack) => stack.identifier === stackId);
}

/**
 * Count services per category
 */
export function getServiceCountByCategory(categoryId: string): number {
  return getServicesByCategory(categoryId).length;
}

/**
 * Get related services for a given service
 */
export function getRelatedServices(service: Service): Service[] {
  const services = getServices();
  return service.related
    .map((id) => services.find((s) => s.identifier === id))
    .filter((s): s is Service => s !== undefined);
}

/**
 * Get required services (dependencies) for a given service
 */
export function getRequiredServices(service: Service): Service[] {
  const services = getServices();
  return service.requires
    .map((id) => services.find((s) => s.identifier === id))
    .filter((s): s is Service => s !== undefined);
}
