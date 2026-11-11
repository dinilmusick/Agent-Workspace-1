#!/usr/bin/env bash
set -euo pipefail

test -d "$GITHUB_WORKSPACE/source/src/engine" || { echo "Private Fod-Engine source checkout is missing." >&2; exit 1; }
mkdir -p src/backend/workflows/engine/types
cp -R $GITHUB_WORKSPACE/source/src/engine/. src/backend/workflows/engine/
cp $GITHUB_WORKSPACE/source/src/shared/types/graph.ts src/backend/workflows/engine/types/graph.ts

python3 - <<'PY'
from pathlib import Path
import re

root = Path("src/backend/workflows/engine")
for path in root.rglob("*.ts"):
    text = path.read_text()
    text = text.replace("../../shared/types/graph", "../types/graph")
    text = text.replace("../../../shared/types/graph", "../../types/graph")
    path.write_text(text)

p = root / "registry/index.ts"
s = p.read_text()
s = s.replace("  private static instance: NodeRegistry;\n", "")
s = s.replace("""  private constructor() {}

  static getInstance(): NodeRegistry {
    if (!NodeRegistry.instance) {
      NodeRegistry.instance = new NodeRegistry();
    }
    return NodeRegistry.instance;
  }

  register(definition: NodeDefinition): void {
    this.registry.set(definition.metadata.type, definition);
  }""", """  constructor() {}

  register(definition: NodeDefinition, nativeExecution = false): void {
    const registered = nativeExecution
      ? { ...definition, metadata: { ...definition.metadata, nativeExecution: true } }
      : definition;
    this.registry.set(registered.metadata.type, registered);
  }""")
s = s.replace("return Array.from(this.registry.values());", "return Array.from(this.registry.values()).sort((a, b) => a.metadata.type.localeCompare(b.metadata.type));")
p.write_text(s)

for name in ["core", "math", "logic", "string", "collections", "parsing", "networking", "utilities", "ai", "database"]:
    p = root / f"nodes/{name}.ts"
    s = p.read_text()
    for fn in ["registerCoreNodes", "registerMathNodes", "registerLogicNodes", "registerStringNodes",
               "registerCollectionsNodes", "registerParsingNodes", "registerNetworkingNodes", "registerUtilitiesNodes",
               "registerAiNodes", "registerDatabaseNodes"]:
        s = s.replace(f"export function {fn}() {{\n  const registry = NodeRegistry.getInstance();",
                      f"export function {fn}(registry: NodeRegistry) {{")
    s = re.sub(r"registry\.register\((\w+)\);", r"registry.register(\1, true);", s)
    p.write_text(s)

p = root / "nodes/presets.ts"
s = p.read_text().replace(
    "export function registerPresetNodes() {\n  const registry = NodeRegistry.getInstance();",
    "export function registerPresetNodes(registry: NodeRegistry) {"
)
# The standalone proxy-backed fetch preset is not part of the native engine.
s = re.sub(r'  "networking/fetch": \{.*?\n  \},\n  "networking/websocket":',
           '  "networking/websocket":', s, flags=re.S)
p.write_text(s)

(root / "nodes/index.ts").write_text("""import { NodeRegistry } from "../registry";
import { registerPresetNodes } from "./presets";
import { registerCoreNodes } from "./core";
import { registerMathNodes } from "./math";
import { registerLogicNodes } from "./logic";
import { registerStringNodes } from "./string";
import { registerCollectionsNodes } from "./collections";
import { registerParsingNodes } from "./parsing";
import { registerNetworkingNodes } from "./networking";
import { registerAiNodes } from "./ai";
import { registerDatabaseNodes } from "./database";
import { registerUtilitiesNodes } from "./utilities";
import { registerRuntimeNodes } from "./runtime";

export function registerAllNodes(registry: NodeRegistry): NodeRegistry {
  registerPresetNodes(registry);
  registerCoreNodes(registry);
  registerMathNodes(registry);
  registerLogicNodes(registry);
  registerStringNodes(registry);
  registerCollectionsNodes(registry);
  registerParsingNodes(registry);
  registerNetworkingNodes(registry);
  registerAiNodes(registry);
  registerDatabaseNodes(registry);
  registerUtilitiesNodes(registry);
  registerRuntimeNodes(registry);
  return registry;
}
""")

(root / "nodes/runtime.ts").write_text("""import { NodeRegistry, type NodeDefinition } from "../registry";
import type { MemoryStore } from "../memory";
import type { ExecutionContext } from "../executor/context";

function scope(context?: ExecutionContext) {
  if (!context?.workspaceId || !context.principal || !context.services.runtime ||
      context.principal.verified !== true || context.principal.workspaceId !== context.workspaceId) {
    throw new Error("Runtime nodes require a verified Luth principal, matching workspace, and Aiko RuntimeService facade.");
  }
  return { workspaceId: context.workspaceId, principal: context.principal, runtime: context.services.runtime, signal: context.signal };
}
const definitions: NodeDefinition[] = [
  {
    metadata: { type: "runtime/spawn", category: "utilities", displayName: "Spawn Runtime", description: "Allocate an Aiko-managed provider runtime.", nativeExecution: true },
    inputs: {
      providerId: { type: "string", label: "Provider ID" }, accountId: { type: "string", label: "Runtime Account ID" },
      configuration: { type: "object", label: "Provider Configuration", defaultValue: {} },
      source: { type: "object", label: "Source", defaultValue: {} },
      injectedInputs: { type: "object", label: "Injected Inputs", defaultValue: {} },
      persistence: { type: "string", label: "Persistence", defaultValue: "transient" }
    },
    outputs: { runtime: { type: "object", label: "Runtime Handle" } },
    async execute(inputs, _memory: MemoryStore, _nodeId: string, context?: ExecutionContext) {
      const s = scope(context);
      const runtime = await s.runtime.spawn({
        workspaceId: s.workspaceId, executionId: context!.executionId,
        providerId: String(inputs.providerId || ""), accountId: String(inputs.accountId || ""),
        configuration: (inputs.configuration || {}) as Record<string, unknown>,
        source: (inputs.source || {}) as Record<string, unknown>,
        injectedInputs: (inputs.injectedInputs || {}) as Record<string, unknown>,
        persistence: inputs.persistence === "persistent" ? "persistent" : "transient"
      }, s.principal, s.signal);
      return { runtime };
    }
  },
  {
    metadata: { type: "runtime/execute", category: "utilities", displayName: "Execute Command", description: "Execute a command through Aiko RuntimeService.", nativeExecution: true },
    inputs: {
      runtime: { type: "object", label: "Runtime Handle" }, command: { type: "string", label: "Command" },
      workingDirectory: { type: "string", label: "Working Directory" }, timeoutMs: { type: "number", label: "Timeout (ms)" },
      environment: { type: "object", label: "Environment", defaultValue: {} }
    },
    outputs: {
      runtime: { type: "object", label: "Updated Runtime Handle" }, result: { type: "object", label: "Command Result" },
      stdout: { type: "string", label: "Standard Output" }, stderr: { type: "string", label: "Standard Error" },
      exitCode: { type: "number", label: "Exit Code" }
    },
    async execute(inputs, _memory: MemoryStore, _nodeId: string, context?: ExecutionContext) {
      const s = scope(context);
      const handle = inputs.runtime as { id?: string; workspaceId?: string } | undefined;
      if (!handle?.id || handle.workspaceId !== s.workspaceId) throw new Error("Runtime handle is outside the active workspace.");
      const result = await s.runtime.execute({
        workspaceId: s.workspaceId, runtimeId: handle.id, command: String(inputs.command || ""),
        ...(typeof inputs.workingDirectory === "string" ? { workingDirectory: inputs.workingDirectory } : {}),
        ...(typeof inputs.timeoutMs === "number" ? { timeoutMs: inputs.timeoutMs } : {}),
        environment: (inputs.environment || {}) as Record<string, string>
      }, s.principal, s.signal);
      return { runtime: result.handle, result: result.result, stdout: result.result.stdout, stderr: result.result.stderr, exitCode: result.result.exitCode };
    }
  },
  {
    metadata: { type: "runtime/status", category: "utilities", displayName: "Runtime Status", description: "Read Aiko runtime lifecycle state.", nativeExecution: true },
    inputs: { runtime: { type: "object", label: "Runtime Handle" } },
    outputs: { runtime: { type: "object", label: "Updated Runtime Handle" }, status: { type: "string", label: "Lifecycle" } },
    async execute(inputs, _memory: MemoryStore, _nodeId: string, context?: ExecutionContext) {
      const s = scope(context);
      const handle = inputs.runtime as { id?: string; workspaceId?: string } | undefined;
      if (!handle?.id || handle.workspaceId !== s.workspaceId) throw new Error("Runtime handle is outside the active workspace.");
      const runtime = await s.runtime.status({ workspaceId: s.workspaceId, runtimeId: handle.id }, s.principal, s.signal);
      return { runtime, status: String((runtime as any)?.lifecycle || "unknown") };
    }
  },
  {
    metadata: { type: "runtime/destroy", category: "utilities", displayName: "Destroy Runtime", description: "Terminate an Aiko-managed runtime.", nativeExecution: true },
    inputs: { runtime: { type: "object", label: "Runtime Handle" } },
    outputs: { runtime: { type: "object", label: "Terminated Runtime Handle" } },
    async execute(inputs, _memory: MemoryStore, _nodeId: string, context?: ExecutionContext) {
      const s = scope(context);
      const handle = inputs.runtime as { id?: string; workspaceId?: string } | undefined;
      if (!handle?.id || handle.workspaceId !== s.workspaceId) throw new Error("Runtime handle is outside the active workspace.");
      return { runtime: await s.runtime.destroy({ workspaceId: s.workspaceId, runtimeId: handle.id }, s.principal, s.signal) };
    }
  }
];
export function registerRuntimeNodes(registry: NodeRegistry): void {
  definitions.forEach(definition => registry.register(definition, true));
}
export { definitions as RUNTIME_NODE_DEFINITIONS };
""")

(root / "executor/context.ts").write_text("""import { ErrorCollector } from "../error";

export interface VerifiedLuthPrincipal {
  readonly verified: true;
  readonly userId: string;
  readonly workspaceId: string;
  readonly roles?: readonly string[];
}
export interface RuntimeNodeServices {
  spawn(input: Record<string, unknown>, principal: VerifiedLuthPrincipal, signal?: AbortSignal): Promise<unknown>;
  execute(input: Record<string, unknown>, principal: VerifiedLuthPrincipal, signal?: AbortSignal): Promise<{ handle: unknown; result: { stdout: string; stderr: string; exitCode: number; [key: string]: unknown } }>;
  status(input: Record<string, unknown>, principal: VerifiedLuthPrincipal, signal?: AbortSignal): Promise<unknown>;
  destroy(input: Record<string, unknown>, principal: VerifiedLuthPrincipal, signal?: AbortSignal): Promise<unknown>;
  cleanupExecution(input: { workspaceId: string; executionId: string }, principal: VerifiedLuthPrincipal): Promise<unknown>;
}
export interface GraphExecutionServices {
  readonly runtime?: RuntimeNodeServices;
  readonly ai?: { generate(prompt: string, data: Record<string, unknown>, principal?: VerifiedLuthPrincipal, signal?: AbortSignal): Promise<string> };
  readonly libraries?: Readonly<Record<string, unknown>>;
}
export interface SchedulerInterface {
  getIsCancelled(): boolean;
  logMessage(message: string, level: "info" | "success" | "warn" | "error" | "ai", nodeId?: string): void;
}
export class ExecutionContext {
  public readonly executionId: string;
  public readonly workspaceId?: string;
  public readonly principal?: VerifiedLuthPrincipal;
  public readonly services: GraphExecutionServices;
  public readonly startTime: number;
  private variables: Record<string, any> = {};
  private runtimeObjects = new Map<string, any>();
  private activeConnections = new Set<string>();
  public readonly errorCollector = new ErrorCollector();
  private schedulerRef: SchedulerInterface;
  private controller = new AbortController();
  private externalSignal?: AbortSignal;
  private externalAbort?: () => void;
  public readonly signal: AbortSignal;
  constructor(scheduler: SchedulerInterface, initialVariables: Record<string, any> = {}, executionId?: string, workspaceId?: string, principal?: VerifiedLuthPrincipal, services: GraphExecutionServices = {}, signal?: AbortSignal) {
    this.executionId = executionId || globalThis.crypto.randomUUID();
    this.workspaceId = workspaceId;
    this.principal = principal;
    this.services = services;
    this.startTime = Date.now();
    this.schedulerRef = scheduler;
    this.variables = { ...initialVariables };
    this.externalSignal = signal;
    this.signal = this.controller.signal;
    if (signal) {
      this.externalAbort = () => this.cancel();
      if (signal.aborted) this.controller.abort(signal.reason);
      else signal.addEventListener("abort", this.externalAbort, { once: true });
    }
  }
  getScheduler(): SchedulerInterface { return this.schedulerRef; }
  getVariable(name: string): any { return this.variables[name]; }
  setVariable(name: string, value: any): void { this.variables[name] = value; }
  getVariables(): Record<string, any> { return { ...this.variables }; }
  registerRuntimeObject(id: string, obj: any): void { this.runtimeObjects.set(id, obj); }
  getRuntimeObject(id: string): any { return this.runtimeObjects.get(id); }
  unregisterRuntimeObject(id: string): void { this.runtimeObjects.delete(id); }
  registerActiveConnection(id: string): void { this.activeConnections.add(id); }
  unregisterActiveConnection(id: string): void { this.activeConnections.delete(id); }
  cancel(): void { if (!this.controller.signal.aborted) this.controller.abort(); }
  isCancelled(): boolean { return this.signal.aborted || this.schedulerRef.getIsCancelled(); }
  log(message: string, level: "info" | "success" | "warn" | "error" | "ai" = "info", nodeId?: string): void { this.schedulerRef.logMessage(message, level, nodeId); }
  dispose(): void {
    if (this.externalSignal && this.externalAbort) this.externalSignal.removeEventListener("abort", this.externalAbort);
    for (const [id, obj] of this.runtimeObjects) {
      try {
        if (typeof obj?.close === "function") obj.close();
        else if (typeof obj?.destroy === "function") obj.destroy();
        else if (typeof obj?.dispose === "function") obj.dispose();
      } catch (error) { this.log("Failed to dispose runtime object " + id + ": " + String(error), "warn"); }
    }
    this.runtimeObjects.clear();
    this.activeConnections.clear();
  }
}
""")

p = root / "executor/index.ts"
s = p.read_text()
s = s.replace("  context?: ExecutionContext\n): Promise<Record<string, any>> {\n  const registry = NodeRegistry.getInstance();",
              "  context?: ExecutionContext,\n  registry: NodeRegistry = new NodeRegistry()\n): Promise<Record<string, any>> {")
a = s.find("      // Server-side AI generator proxy helper")
b = s.find("      // Retrieve state variables", a)
if a >= 0 and b > a:
    s = s[:a] + """      const aiHelper = {
        generate: async (prompt: string, contextData: any = {}) => {
          if (!context?.services.ai) throw new Error("No Aiko AI service was provided to this graph execution.");
          return context.services.ai.generate(prompt, contextData, context.principal, context.signal);
        }
      };

""" + s[b:]
a = s.find("      // Load installed dependencies dynamically via ESM.sh CDN at runtime!")
b = s.find("      // Prepare function parameters", a)
if a >= 0 and b > a:
    s = s[:a] + """      const loadedLibs: Record<string, any> = { ...(context?.services.libraries || {}) };
      const requestedLibraries = (graph as any).libraries || [];
      for (const lib of requestedLibraries) {
        if (!loadedLibs[lib.alias || lib.name]) {
          throw new Error("Graph dependency '" + lib.name + "' was not supplied by Aiko trusted execution services.");
        }
      }

""" + s[b:]
p.write_text(s)

p = root / "scheduler/index.ts"
s = p.read_text()
s = s.replace('import { ExecutionContext } from "../executor/context";',
              'import { ExecutionContext, type GraphExecutionServices, type VerifiedLuthPrincipal } from "../executor/context";\nimport { NodeRegistry } from "../registry";')
s = s.replace('  runtimeConfig?: { aikoApiUrl?: string; aikoModuleToken?: string };',
              '  principal?: VerifiedLuthPrincipal;\n  services?: GraphExecutionServices;\n  signal?: AbortSignal;')
s = s.replace('export class GraphScheduler {\n  private listeners',
              'export class GraphScheduler {\n  constructor(private readonly registry: NodeRegistry) {}\n  private listeners')
s = s.replace('  async run(graph: GraphJSON, initialVariables: Record<string, any> = {}, options: SchedulerExecutionOptions = {}): Promise<MemoryStore> {',
              '  dispose(): void { this.currentContext?.dispose(); this.currentContext = null; this.activeMemory = null; this.activeNodeId = null; }\n\n  async run(graph: GraphJSON, initialVariables: Record<string, any> = {}, options: SchedulerExecutionOptions = {}): Promise<MemoryStore> {')
s = s.replace('const context = new ExecutionContext(this, initialVariables, options.executionId, options.workspaceId || (graph as any).settings?.workspaceId, options.runtimeConfig);',
              'const context = new ExecutionContext(this, initialVariables, options.executionId, options.workspaceId || (graph as any).settings?.workspaceId, options.principal, options.services, options.signal);\n    const abortHandler = () => this.cancel();\n    options.signal?.addEventListener("abort", abortHandler, { once: true });\n    if (options.signal?.aborted) this.cancel();')
s = s.replace('executeNode(node, graph, memory, context)', 'executeNode(node, graph, memory, context, this.registry)')
s = s.replace('executeNode(bNode, graph, memory, context)', 'executeNode(bNode, graph, memory, context, this.registry)')
s = s.replace('      return memory;\n    }\n\n    validationErrors.forEach',
              '      memory.setError("__graph__", errorMsg);\n      context.dispose();\n      options.signal?.removeEventListener("abort", abortHandler);\n      return memory;\n    }\n\n    validationErrors.forEach', 1)
s = s.replace('          context.dispose();\n          return memory;',
              '          context.dispose();\n          options.signal?.removeEventListener("abort", abortHandler);\n          return memory;')
s = s.replace('    context.dispose();\n\n    this.activeNodeId = null;',
              '    context.dispose();\n    options.signal?.removeEventListener("abort", abortHandler);\n\n    this.activeNodeId = null;')
p.write_text(s)

# SDK registry also becomes engine-owned and adapts SDK nodes through the same
# scheduler-provided execution context, not a synthetic global context.
p = root / "sdk/registry/index.ts"
s = p.read_text()
s = s.replace("  private static instance: SDKRegistry;\n", "")
s = s.replace("  private constructor() {}\n\n  static getInstance(): SDKRegistry {\n    if (!SDKRegistry.instance) {\n      SDKRegistry.instance = new SDKRegistry();\n    }\n    return SDKRegistry.instance;\n  }",
              "  constructor(private readonly registry: NodeRegistry) {}")
s = s.replace("      execute: async (inputs, memory, nodeId) => {",
              "      execute: async (inputs, memory, nodeId, executionContext) => {")
s = s.replace("        const context = new ExecutionContext(schedulerMock, memory.getAllOutputs());",
              "        const context = executionContext || new ExecutionContext(schedulerMock, memory.getVariables());")
s = s.replace("    NodeRegistry.getInstance().register(adaptedDefinition);",
              "    this.registry.register(adaptedDefinition, true);")
p.write_text(s)

# The SDK's type module path was relocated with the graph contracts.
p = root / "sdk/types/index.ts"
p.write_text(p.read_text().replace("../../../shared/types/graph", "../../types/graph"))

(root / "index.ts").write_text("""import { randomUUID } from "node:crypto";
import { NodeRegistry, type NodeDefinition } from "./registry";
import { registerAllNodes } from "./nodes";
import { GraphScheduler, validateGraph, planGraphExecution } from "./scheduler";
import { MemoryStore, type LogEntry } from "./memory";
import { SDKRegistry } from "./sdk/registry";
import type { GraphJSON, NodeJSON, EdgeJSON } from "./types/graph";
import type { GraphExecutionServices, VerifiedLuthPrincipal } from "./executor/context";

export type { GraphJSON, NodeJSON, EdgeJSON } from "./types/graph";
export type { NodeDefinition, NodePortDefinition, NodeMetadata } from "./registry";
export type { SchedulerEvent, SchedulerEventType, SchedulerListener } from "./scheduler";
export type { GraphExecutionServices, VerifiedLuthPrincipal, RuntimeNodeServices } from "./executor/context";
export { MemoryStore, validateGraph, planGraphExecution, registerAllNodes, NodeRegistry, SDKRegistry };

export interface GraphExecutionOptions {
  workspaceId: string;
  principal: VerifiedLuthPrincipal;
  executionId?: string;
  variables?: Record<string, unknown>;
  services?: GraphExecutionServices;
  signal?: AbortSignal;
}
export interface GraphExecutionResult {
  executionId: string;
  workspaceId: string;
  success: boolean;
  cancelled: boolean;
  outputs: Record<string, Record<string, unknown>>;
  variables: Record<string, unknown>;
  logs: LogEntry[];
  errors: Record<string, string>;
}
export class GraphEngine {
  readonly registry: NodeRegistry;
  readonly sdk: SDKRegistry;
  private readonly active = new Map<string, GraphScheduler>();
  constructor(registry?: NodeRegistry) {
    this.registry = registry || registerAllNodes(new NodeRegistry());
    this.sdk = new SDKRegistry(this.registry);
  }
  getNodeDefinitions(): NodeDefinition[] { return this.registry.getAllDefinitions(); }
  validate(graph: GraphJSON) { return validateGraph(graph); }
  plan(graph: GraphJSON) { return planGraphExecution(graph); }
  cancel(executionId: string): boolean {
    const scheduler = this.active.get(executionId);
    if (!scheduler) return false;
    scheduler.cancel();
    return true;
  }
  async execute(graph: GraphJSON, options: GraphExecutionOptions): Promise<GraphExecutionResult> {
    if (!options.workspaceId || !options.principal?.userId || options.principal.verified !== true) {
      throw new Error("Graph execution requires a verified Luth principal and workspace context.");
    }
    if (options.principal.workspaceId !== options.workspaceId) {
      throw new Error("Verified Luth principal does not belong to the requested workspace.");
    }
    const executionId = options.executionId || randomUUID();
    if (this.active.has(executionId)) throw new Error("Execution ID is already active.");
    const scheduler = new GraphScheduler(this.registry);
    this.active.set(executionId, scheduler);
    try {
      const memory = await scheduler.run(graph, { ...(graph.variables || {}), ...(options.variables || {}) }, {
        executionId, workspaceId: options.workspaceId, principal: options.principal,
        services: options.services, signal: options.signal
      });
      const errors = memory.getErrors();
      const cancelled = scheduler.getIsCancelled();
      return {
        executionId, workspaceId: options.workspaceId,
        success: !cancelled && Object.keys(errors).length === 0,
        cancelled, outputs: memory.getAllOutputs(), variables: memory.getVariables(),
        logs: memory.getLogs(), errors
      };
    } finally {
      try {
        await options.services?.runtime?.cleanupExecution({ workspaceId: options.workspaceId, executionId }, options.principal);
      } finally {
        scheduler.dispose();
        this.active.delete(executionId);
      }
    }
  }
}
export function createGraphEngine(): GraphEngine { return new GraphEngine(); }
""")

# Culled source categories still participate in explicit registry wiring.
for name, function_name in [
    ("ai", "registerAiNodes"), ("database", "registerDatabaseNodes"),
    ("string", "registerStringNodes"), ("parsing", "registerParsingNodes")
]:
    p = root / f"nodes/{name}.ts"
    content = p.read_text()
    content = content.replace(
        f"export function {function_name}() {{",
        f'import type {{ NodeRegistry }} from "../registry";\nexport function {function_name}(_registry: NodeRegistry) {{'
    )
    p.write_text(content)

# The SDK verification helper must use an engine-owned registry, not deleted singletons.
p = root / "sdk/test-sdk.ts"
content = p.read_text()
content = content.replace(
    "  const sdkRegistry = SDKRegistry.getInstance();\n  sdkRegistry.registerNode(TestMathNode);\n  \n  const registeredNode = NodeRegistry.getInstance().getDefinition(\"sdk/test-math\");",
    "  const nodeRegistry = new NodeRegistry();\n  const sdkRegistry = new SDKRegistry(nodeRegistry);\n  sdkRegistry.registerNode(TestMathNode);\n  \n  const registeredNode = nodeRegistry.getDefinition(\"sdk/test-math\");"
)
p.write_text(content)

# Fix the source scheduler's data-only graph path and persist all node failures in MemoryStore.
p = root / "scheduler/index.ts"
content = p.read_text()
content = content.replace(
    "      if (isPureNode) {\\n        return !isConnectedToActiveFlow(nodeId);\\n      }",
    "      if (isPureNode) {\\n        return hasAnyExecEdges && !isConnectedToActiveFlow(nodeId);\\n      }"
)
content = content.replace(
    "        } catch (err: any) {\\n          nodeState[bodyNodeId] = \"failed\";",
    "        } catch (err: any) {\\n          memory.setError(bodyNodeId, err instanceof Error ? err.message : String(err));\\n          nodeState[bodyNodeId] = \"failed\";"
)
content = content.replace(
    "        } catch (err: any) {\\n          nodeState[nodeId] = \"failed\";",
    "        } catch (err: any) {\\n          memory.setError(nodeId, err instanceof Error ? err.message : String(err));\\n          nodeState[nodeId] = \"failed\";"
)
content = content.replace(
    "      } catch (err: any) {\\n        nodeState[nodeId] = \"failed\";",
    "      } catch (err: any) {\\n        memory.setError(nodeId, err instanceof Error ? err.message : String(err));\\n        nodeState[nodeId] = \"failed\";"
)
p.write_text(content)

# Emit NodeNext-compatible .js specifiers for relative TypeScript imports, including
# directory index modules. This is the convention already used throughout Aiko.
import re
for path in root.rglob("*.ts"):
    content = path.read_text()
    def fix_specifier(match):
        prefix, specifier, suffix = match.groups()
        if not specifier.startswith(".") or Path(specifier).suffix:
            return match.group(0)
        candidate = (path.parent / specifier).resolve()
        if candidate.is_dir() and (candidate / "index.ts").exists():
            specifier = specifier.rstrip("/") + "/index.js"
        elif candidate.with_suffix(".ts").exists():
            specifier += ".js"
        elif candidate.with_suffix(".tsx").exists():
            specifier += ".js"
        return prefix + specifier + suffix
    content = re.sub(r'(["\'])(\.{1,2}/[^"\']+)(["\'])', fix_specifier, content)
    path.write_text(content)

# Remove the source repository's test, which exercised the deleted FOD HTTP bridge.
(root / "nodes/runtime.test.ts").unlink(missing_ok=True)
PY

cat > src/backend/workflows/engine.test.ts <<'TS'
import test from "node:test";
import assert from "node:assert/strict";
import { GraphEngine } from "./engine/index.js";
import type { GraphJSON, VerifiedLuthPrincipal } from "./engine/index.js";

const principal: VerifiedLuthPrincipal = { verified: true, userId: "user-1", workspaceId: "workspace-1" };
const graph = (nodes: GraphJSON["nodes"], edges: GraphJSON["edges"] = []): GraphJSON => ({
  nodes, edges, variables: {}, metadata: { id: "graph-1", name: "test", description: "", version: "1" }, settings: { executionDelayMs: 0 }
} as GraphJSON);
const node = (id: string, type: string, data: Record<string, unknown> = {}) => ({
  id, type, position: { x: 0, y: 0 }, data
});

test("executes native graph nodes and routes connected data", async () => {
  const result = await new GraphEngine().execute(graph(
    [node("sum", "math/add", { addend: 4 }), node("product", "math/multiply", { factor: 3 })],
    [{ id: "edge-1", source: "sum", sourceHandle: "result", target: "product", targetHandle: "factor" }]
  ), { workspaceId: "workspace-1", principal, executionId: "execution-dataflow" });
  assert.equal(result.success, true);
  assert.equal(result.outputs.sum.result, 4);
  assert.equal(result.outputs.product.result, 12);
});

test("isolates registries between engine instances", () => {
  const first = new GraphEngine();
  const second = new GraphEngine();
  first.registry.register({
    metadata: { type: "test/only-first", category: "custom", displayName: "First only", description: "" },
    inputs: {}, outputs: {}, async execute() { return { result: true }; }
  }, true);
  assert.ok(first.getNodeDefinitions().some(item => item.metadata.type === "test/only-first"));
  assert.ok(!second.getNodeDefinitions().some(item => item.metadata.type === "test/only-first"));
});

test("rejects a principal from a different workspace", async () => {
  await assert.rejects(() => new GraphEngine().execute(graph([]), {
    workspaceId: "workspace-2", principal
  }), /does not belong/);
});

test("propagates verified principal and cancellation signal through the runtime facade", async () => {
  const controller = new AbortController();
  let received: any;
  let cleanupCalls = 0;
  const result = await new GraphEngine().execute(graph([node("spawn", "runtime/spawn", {
    providerId: "mock", accountId: "account-1", configuration: {}, persistence: "transient"
  })]), {
    workspaceId: "workspace-1", principal, signal: controller.signal,
    services: { runtime: {
      async spawn(input, verifiedPrincipal, signal) {
        received = { input, verifiedPrincipal, signal };
        return { id: "runtime-1", workspaceId: "workspace-1" };
      },
      async execute() { throw new Error("unused"); },
      async status() { throw new Error("unused"); },
      async destroy() { throw new Error("unused"); },
      async cleanupExecution(input, verifiedPrincipal) {
        cleanupCalls += 1;
        assert.equal(input.workspaceId, "workspace-1");
        assert.equal(input.executionId, received.input.executionId);
        assert.equal(verifiedPrincipal.userId, "user-1");
      }
    } }
  });
  assert.equal(result.success, true);
  assert.equal(received.verifiedPrincipal.userId, "user-1");
  assert.equal(received.input.executionId, result.executionId);
  assert.equal(received.signal.aborted, false);
  assert.equal("token" in received.verifiedPrincipal, false);
  assert.equal(cleanupCalls, 1);
});

test("reports node failures without claiming success", async () => {
  const result = await new GraphEngine().execute(graph([node("missing", "unknown/node")]), {
    workspaceId: "workspace-1", principal
  });
  assert.equal(result.success, false);
  assert.match(result.errors.missing, /not registered/);
});

test("honors cancellation for an active execution", async () => {
  const controller = new AbortController();
  const pending = new GraphEngine().execute(graph([node("delay", "utilities/delay", { milliseconds: 30 })]), {
    workspaceId: "workspace-1", principal, executionId: "execution-cancel", signal: controller.signal
  });
  setTimeout(() => controller.abort(), 5);
  const result = await pending;
  assert.equal(result.cancelled, true);
  assert.equal(result.success, false);
});
TS

npm install --package-lock=false --no-audit --no-fund

set +e
failed_scoped=0
run_check() {
  label="$1"; shift
  log="/tmp/aiko-engine-${label}.log"
  echo "===== START ${label} ====="
  "$@" >"$log" 2>&1
  code=$?
  echo "===== EXIT ${label}: ${code} ====="
  if [ "$code" -eq 0 ]; then tail -12 "$log"; else tail -50 "$log"; fi
  case "$label" in
    focused-tests|scoped-types) [ "$code" -eq 0 ] || failed_scoped=1 ;;
  esac
}
run_check focused-tests node --import tsx --test src/backend/workflows/engine.test.ts
run_check scoped-types npx tsc --noEmit --skipLibCheck --target ES2022 --module NodeNext --moduleResolution NodeNext src/backend/workflows/engine.test.ts
run_check full-lint npm run lint
run_check full-tests npm test
run_check api-build npm run build:api
run_check app-build npm run build

python3 - <<'PY'
from pathlib import Path
root = Path("src/backend/workflows/engine")
forbidden = ("FOD_BASE_URL", "AIKO_API_URL", "AIKO_MODULE_TOKEN", "/api/proxy", "/api/run-ai", "esm.sh", "NodeRegistry.getInstance", "SDKRegistry.getInstance")
hits = []
for path in root.rglob("*.ts"):
    content = path.read_text()
    for marker in forbidden:
        if marker in content:
            hits.append(f"{path}: {marker}")
if hits:
    raise SystemExit("Engine boundary violations:\n" + "\n".join(hits))
print(f"Engine boundary scan passed ({sum(1 for _ in root.rglob('*.ts'))} TypeScript files).")
PY
[ "$failed_scoped" -eq 0 ]
