/**
 * Stack component - a service within a stack
 */
export type StackComponent = {
  /** Service identifier from services.json */
  service: string;
  /** Installation order (1 = first) */
  position: number;
  /** If true, this component is optional */
  optional?: boolean;
  /** Role description within the stack */
  note?: string;
};

/**
 * Stack type for UIS service stacks.
 * Maps to stacks.json structure (JSON-LD SoftwareSourceCode).
 */
export type Stack = {
  /** Unique identifier (lowercase, hyphenated) */
  identifier: string;
  /** Display name */
  name: string;
  /** Brief description */
  description: string;
  /** Reference to category codeValue */
  category: string;
  /** Logo filename (SVG) in static/img/stacks/ */
  logo: string;
  /** Detailed description */
  summary: string;
  /** Services in this stack, in installation order */
  components: StackComponent[];
};

/**
 * Props for StackCard component
 */
export type StackCardProps = {
  stack: Stack;
};

/**
 * Props for StackGrid component
 */
export type StackGridProps = {
  /** Section title */
  title?: string;
};

/**
 * Props for ServiceFlowDiagram component
 */
export type ServiceFlowDiagramProps = {
  /** Stack components to display */
  components: StackComponent[];
  /** Show service names below logos */
  showNames?: boolean;
};
