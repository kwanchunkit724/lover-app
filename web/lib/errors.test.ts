import { test } from "node:test";
import assert from "node:assert/strict";
import { errMsg } from "./errors";

test("errMsg: null/undefined", () => {
  assert.equal(errMsg(null), "(unknown error)");
  assert.equal(errMsg(undefined), "(unknown error)");
});

test("errMsg: string + Error", () => {
  assert.equal(errMsg("boom"), "boom");
  assert.equal(errMsg(new Error("nope")), "nope");
});

test("errMsg: Postgrest-shaped object", () => {
  assert.equal(
    errMsg({ message: "invalid_code", code: "P0001", hint: "try again" }),
    "invalid_code (P0001 · try again)",
  );
  assert.equal(errMsg({ message: "only" }), "only");
});

test("errMsg: plain object without message falls back to JSON", () => {
  assert.equal(errMsg({ code: 42 }), JSON.stringify({ code: 42 }));
});
