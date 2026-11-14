export const GOAL_TYPES = [
  "coding","learning","research","design","creative","operations",
  "business","personal_development","maintenance","system","general",
] as const;

export const TASK_TYPES = [
  "implementation","investigation","research","design","learning",
  "verification","documentation","maintenance","operations","review","general",
] as const;

export const TARGET_TYPES = [
  "repository","person","application","service","database","workspace",
  "document","organization","system","device","general",
] as const;

export type GoalType = (typeof GOAL_TYPES)[number];
export type TaskType = (typeof TASK_TYPES)[number];
export type TargetType = (typeof TARGET_TYPES)[number];

export interface Target {
  type: TargetType;
  id: string;
  label?: string;
  uri?: string;
  metadata?: Record<string, unknown>;
}

export interface UniverseDefinition {
  id: string;
  universeKey: string;
  ownerUserId?: string;
  name: string;
  description?: string;
  parameters: Record<string, unknown>;
  metadata: Record<string, unknown>;
  status: "planned" | "active" | "paused" | "archived" | "retired";
  contextVersion: number;
}

export interface SystemDefinition {
  id: string;
  universeId: string;
  systemKey: string;
  parentSystemId?: string;
  name: string;
  systemType: string;
  description: string;
  status: "planned" | "active" | "paused" | "archived" | "retired";
  parameters: Record<string, unknown>;
  metadata: Record<string, unknown>;
  contextVersion: number;
}

export interface SystemMemoryDefinition {
  id: string;
  systemId: string;
  memoryKey: string;
  title: string;
  content: string;
  memoryType:
    | "general" | "decision" | "constraint" | "observation"
    | "change" | "fact" | "warning" | "milestone";
  importance: number;
  status: "active" | "superseded" | "archived";
  occurredAt: string;
  sourceType?: string;
  sourceId?: string;
  metadata: Record<string, unknown>;
}

export interface SystemFunctionDefinition {
  id: string;
  systemId: string;
  functionKey: string;
  name: string;
  description: string;
  inputContract: Record<string, unknown>;
  outputContract: Record<string, unknown>;
  transformation: string;
  improvementTarget: Record<string, unknown>;
  acceptanceCriteria: unknown[];
  status: "planned" | "active" | "paused" | "retired";
  metadata: Record<string, unknown>;
}

export interface SystemFunctionSystemLink {
  functionId: string;
  systemId: string;
  contribution: string;
  ordinal: number;
  metadata: Record<string, unknown>;
}

export interface SystemRelationship {
  id: string;
  sourceSystemId: string;
  targetSystemId: string;
  relationType:
    | "depends_on" | "integrates_with" | "interacts_with"
    | "hosts" | "deployed_on" | "derived_from" | "related_to";
  description: string;
  metadata: Record<string, unknown>;
}

export interface SystemWormhole {
  id: string;
  sourceSystemId: string;
  targetSystemId: string;
  status: "pending" | "active" | "paused" | "closed";
  syncMode: "bidirectional" | "source_to_target" | "target_to_source";
  syncScope: Record<string, boolean>;
  description?: string;
  metadata: Record<string, unknown>;
  lastSyncedAt?: string;
}

export interface OmniLoopEdit {
  id: string;
  description: string;
  change: unknown;
}

export interface OmniLoopContract {
  kind: "omni";
  target: Target;
  objective: string;
  edits: OmniLoopEdit[];
  inputContract: Record<string, unknown>;
  outputContract: Record<string, unknown>;
  transformation: string;
  observation: Record<string, unknown>;
  evaluation: Record<string, unknown>;
  revisionPolicy: Record<string, unknown>;
  stopConditions: string[];
  initialInput: unknown;
  tools: string[];
  iterationPolicy: Record<string, unknown>;
  maxIterations: number;
}

export interface GoalDefinition {
  id: string;
  type: GoalType;
  title: string;
  description: string;
  target: Target;
  behaviorInputs: unknown[];
  expectedOutputs: unknown[];
  acceptanceCriteria: unknown[];
  loop: OmniLoopContract;
}

export interface TaskDefinition {
  id: string;
  type: TaskType;
  title: string;
  description: string;
  target: Target;
  acceptanceCriteria: unknown[];
  loop: OmniLoopContract;
}

export interface VisionDefinition {
  id: string;
  title: string;
  description: string;
  target: Target;
  decompositionGraph: {
    nodes: Array<{ id: string; target: Target; parentId?: string }>;
    edges: Array<{ from: string; to: string; relation: string }>;
  };
  tldraw: {
    workspaceId?: string;
    boardId?: string;
    boardUrl?: string;
    overviewPageId?: string;
  };
}
