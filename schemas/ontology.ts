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
