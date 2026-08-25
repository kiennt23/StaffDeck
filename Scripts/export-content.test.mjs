import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  buildContent,
  extractArray,
  parseJson,
  serializeContent,
} from "./export-content-lib.mjs";

const fixtureRoot = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "fixtures",
  "export-content",
);

const fixtureRules = Object.freeze({
  minimumWebFlashcards: 2,
  minimumAdditions: 1,
  minimumFundamentals: 2,
  minimumWebPractices: 2,
  expectedFlashcards: 4,
  expectedPractices: 3,
  goFlashcardStartID: 4,
  filterSubtopics: { Capacity: [2] },
});

function readFixture(filename) {
  return fs.readFileSync(path.join(fixtureRoot, filename), "utf8");
}

function readJsonFixture(filename) {
  return parseJson(readFixture(filename), `fixture ${filename}`);
}

function fixtureInputs() {
  return {
    webFlashcards: extractArray(readFixture("flashcards.ts"), "flashcards.ts", "flashcards"),
    additions: readJsonFixture("additions.json"),
    fundamentalTopics: readJsonFixture("fundamental-topics.json"),
    goFlashcards: readJsonFixture("go-cards.json"),
    answerOverrides: readJsonFixture("answer-overrides.json"),
    webPractices: extractArray(
      readFixture("practice-data.ts"),
      "practice-data.ts",
      "practices",
    ),
    goPractices: readJsonFixture("go-practices.json"),
  };
}

test("valid fixtures produce the expected merged output", () => {
  const result = buildContent(fixtureInputs(), fixtureRules);

  assert.deepEqual(result.flashcards, readJsonFixture("expected-flashcards.json"));
  assert.deepEqual(result.practices, readJsonFixture("expected-practices.json"));
  assert.equal(serializeContent(result.flashcards), readFixture("expected-flashcards.json"));
  assert.equal(serializeContent(result.practices), readFixture("expected-practices.json"));
});

test("malformed source input reports the export and filename", () => {
  assert.throws(
    () => extractArray('export const flashcards = [{"id": 1,}];', "flashcards.ts", "flashcards"),
    /^Error: Cannot parse flashcards from flashcards\.ts: /,
  );
  assert.throws(
    () => extractArray("export const cards = [];", "flashcards.ts", "flashcards"),
    new Error("Cannot find export const flashcards in flashcards.ts"),
  );
});

test("count and ID validations identify the violated contract", () => {
  const tooFewWebCards = fixtureInputs();
  tooFewWebCards.webFlashcards = tooFewWebCards.webFlashcards.slice(0, 1);
  assert.throws(
    () => buildContent(tooFewWebCards, fixtureRules),
    new Error("Expected at least 2 web flashcards, found 1"),
  );

  const invalidMergedID = fixtureInputs();
  invalidMergedID.goFlashcards[0].id = 5;
  assert.throws(
    () => buildContent(invalidMergedID, fixtureRules),
    new Error("Merged flashcard IDs must represent 1 through 4 exactly once"),
  );

  const duplicatePracticeID = fixtureInputs();
  duplicatePracticeID.goPractices[0].id = "practice-1";
  assert.throws(
    () => buildContent(duplicatePracticeID, fixtureRules),
    new Error("Expected 3 practices with unique IDs after merging Go content"),
  );
});

test("answer overrides cannot reference missing base cards", () => {
  const inputs = fixtureInputs();
  inputs.answerOverrides = { 2: "Valid", 99: "Missing" };

  assert.throws(
    () => buildContent(inputs, fixtureRules),
    new Error("Answer overrides reference missing cards: 99"),
  );
});

test("serialization preserves key order, two-space formatting, and one trailing newline", () => {
  const value = [{ second: 2, first: 1 }];
  const expected = '[\n  {\n    "second": 2,\n    "first": 1\n  }\n]\n';

  assert.equal(serializeContent(value), expected);
  assert.equal(Buffer.from(serializeContent(value)).toString("hex"), Buffer.from(expected).toString("hex"));
});
