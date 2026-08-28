import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  exactDuplicateGroups,
  normalizeProse,
  validateRewrittenCards,
} from "./content-quality-lib.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const nativeRoot = path.resolve(scriptDir, "..");
const cards = JSON.parse(
  fs.readFileSync(path.join(nativeRoot, "Content", "go-cards.json"), "utf8"),
);

const knownDuplicateAnswerGroups = [];
const rewrittenCardIDs = Array.from({ length: 93 }, (_, i) => 208 + i);

test("known duplicate answers are explicit and no new groups appear", () => {
  assert.deepEqual(exactDuplicateGroups(cards, "answer"), knownDuplicateAnswerGroups);
});

test("rewritten production cards satisfy the content quality gate", () => {
  validateRewrittenCards(cards, rewrittenCardIDs);
});

test("prose normalization ignores punctuation and capitalization", () => {
  assert.equal(normalizeProse("Typed nil: Go!"), "typed nil go");
});

test("rewritten-card validation rejects shallow or repeated content", () => {
  const shallow = {
    ...cards[0],
    id: 999,
    question: "How should a Go service handle cancellation?",
    answer: "Use context cancellation.",
    testing: "Test cancellation at the service boundary with a deterministic blocked dependency.",
    example: "Cancel a request while its database query is blocked and verify prompt termination.",
    staffSignal: "Connect cancellation ownership to resource cleanup and the caller's deadline budget.",
  };
  assert.throws(
    () => validateRewrittenCards([...cards, shallow], [999]),
    new Error("Rewritten card 999 answer must contain at least 600 characters"),
  );
});
