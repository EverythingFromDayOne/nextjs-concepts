// Placeholder: Cache Components compile check
// Exists so `pnpm --filter next-lab test` has something to run
// until real demo tests land with article routes.
import test from "node:test";
import assert from "node:assert/strict";

test("next-lab scaffold is present", () => {
  assert.equal(1 + 1, 2);
});
