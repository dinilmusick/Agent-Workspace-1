import test from "node:test";
import assert from "node:assert/strict";
import { assertRuntimeClean } from "../scripts/browser-evidence.mjs";

const makeExpect = () => (received, message) => ({
  toEqual(expected) { assert.deepEqual(received, expected, message); }
});

test("allows only explicitly ignored runtime diagnostics", () => {
  const report = {
    consoleErrors: [{ text: "Failed to load resource: 401 (Unauthorized)" }],
    pageErrors: [],
    requestFailures: [],
    httpErrors: [{ status: 401, url: "http://127.0.0.1:4173/api/login" }]
  };
  assertRuntimeClean(report, makeExpect(), ["/api/login", "401 (Unauthorized)"]);
});

test("fails on unapproved runtime diagnostics", () => {
  const report = {
    consoleErrors: [{ text: "Uncaught TypeError: undefined is not a function" }],
    pageErrors: [],
    requestFailures: [],
    httpErrors: []
  };
  assert.throws(() => assertRuntimeClean(report, makeExpect()), /Unexpected browser console/);
});
