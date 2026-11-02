import test from "node:test";
import assert from "node:assert/strict";
import { normalizeVerificationOutput } from "../verifier-worker.mjs";

test("verifier output requires an explicit decision and report", () => {
  assert.deepEqual(normalizeVerificationOutput({
    verified: true,
    verification_report: { checks: [{ name: "build", passed: true }] },
  }), {
    verified: true,
    verification_report: { checks: [{ name: "build", passed: true }] },
    outcome: "Independent verification passed",
  });
  assert.throws(() => normalizeVerificationOutput({ verification_report: {} }), /boolean verified/);
  assert.throws(() => normalizeVerificationOutput({ verified: true }), /verification_report/);
  assert.throws(() => normalizeVerificationOutput({ verified: "yes", verification_report: {} }), /boolean verified/);
});
