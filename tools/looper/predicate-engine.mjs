import { createHash } from "node:crypto";

const BUILTINS = new Map([
  ["builtin.evidence_present", ({ evidence }) => Array.isArray(evidence) && evidence.length > 0],
  ["builtin.boolean_result", ({ result }) => result === true],
]);

export function predicateHash(predicate) {
  return createHash("sha256")
    .update(JSON.stringify({
      key: predicate.key,
      version: predicate.version,
      type: predicate.type,
      definition: predicate.definition,
      inputSchema: predicate.inputSchema,
      expectedResult: predicate.expectedResult,
    }))
    .digest("hex");
}

export async function evaluatePredicate(predicate, input, handlers = {}) {
  if (!predicate?.key || !Number.isInteger(predicate.version)) {
    throw new Error("Predicate requires key and integer version.");
  }

  let result;
  if (predicate.type === "builtin") {
    const handler = BUILTINS.get(predicate.key);
    if (!handler) throw new Error(`Unknown builtin predicate: ${predicate.key}`);
    result = await handler(input ?? {});
  } else if (predicate.type === "cel") {
    const { evaluate } = await import("@marcbachmann/cel-js");
    result = await evaluate(String(predicate.definition?.expression ?? ""), input ?? {});
  } else if (predicate.type === "script") {
    const handler = handlers[predicate.key];
    if (typeof handler !== "function") {
      throw new Error(`No registered handler for script predicate: ${predicate.key}`);
    }
    result = await handler(input ?? {}, predicate);
  } else {
    throw new Error(`Unsupported predicate type: ${predicate.type}`);
  }

  const expected = predicate.expectedResult ?? true;
  const passed = JSON.stringify(result) === JSON.stringify(expected);
  return { result, expected, passed, predicateHash: predicateHash(predicate) };
}

export function registerScriptPredicate(handlers, key, handler) {
  if (!key || typeof handler !== "function") throw new Error("Predicate handler requires a key and function.");
  if (Object.prototype.hasOwnProperty.call(handlers, key)) throw new Error(`Predicate handler already registered: ${key}`);
  handlers[key] = handler;
  return handlers;
}
