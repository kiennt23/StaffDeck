import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import {
  buildContent,
  extractArray,
  parseJson,
  serializeContent,
} from "./export-content-lib.mjs";
import { deriveWebSnapshots } from "./content-snapshot-lib.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const nativeRoot = path.resolve(scriptDir, "..");
const fixtureRoot = path.join(
  scriptDir,
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

function readNative(relativePath) {
  return fs.readFileSync(path.join(nativeRoot, relativePath), "utf8");
}

function readNativeJson(relativePath) {
  return parseJson(readNative(relativePath), relativePath);
}

function productionSnapshotInputs() {
  return {
    generatedFlashcards: readNativeJson("StaffDeck/Resources/flashcards.json"),
    additions: readNativeJson("Content/java-fundamentals-additions.json"),
    goFlashcards: readNativeJson("Content/go-cards.json"),
    generatedPractices: readNativeJson("StaffDeck/Resources/practices.json"),
    goPractices: readNativeJson("Content/go-practices.json"),
  };
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

test("base snapshots derive from and reconstruct the generated resources exactly", () => {
  const inputs = productionSnapshotInputs();
  const snapshots = deriveWebSnapshots(inputs);

  assert.equal(snapshots.webFlashcards.length, 160);
  assert.equal(snapshots.webPractices.length, 208);
  assert.equal(
    serializeContent(snapshots.webFlashcards),
    readNative("Content/base-flashcards.json"),
  );
  assert.equal(
    serializeContent(snapshots.webPractices),
    readNative("Content/base-practices.json"),
  );

  const rebuilt = buildContent({
    ...snapshots,
    additions: inputs.additions,
    fundamentalTopics: readNativeJson("Content/java-fundamentals-topics.json"),
    goFlashcards: inputs.goFlashcards,
    answerOverrides: readNativeJson("Content/flashcard-answer-overrides.json"),
    goPractices: inputs.goPractices,
    practiceMetadata: readNativeJson("Content/practice-metadata.json"),
  });
  assert.equal(serializeContent(rebuilt.flashcards), readNative("StaffDeck/Resources/flashcards.json"));
  assert.equal(serializeContent(rebuilt.practices), readNative("StaffDeck/Resources/practices.json"));
});

test("snapshot derivation rejects duplicate generated IDs", () => {
  const inputs = productionSnapshotInputs();
  inputs.generatedFlashcards.push(inputs.generatedFlashcards[0]);
  assert.throws(
    () => deriveWebSnapshots(inputs),
    new Error(`Duplicate generated flashcard ID: ${inputs.generatedFlashcards[0].id}`),
  );
});

test("snapshot derivation rejects overlapping maintained card ownership", () => {
  const inputs = productionSnapshotInputs();
  inputs.additions.push(inputs.goFlashcards[0]);
  assert.throws(
    () => deriveWebSnapshots(inputs),
    new Error(
      `Flashcard IDs owned by both Java additions and Go content: ${inputs.goFlashcards[0].id}`,
    ),
  );
});

test("snapshot derivation rejects maintained IDs missing from resources", () => {
  const inputs = productionSnapshotInputs();
  inputs.goFlashcards.push({ ...inputs.goFlashcards[0], id: 999 });
  assert.throws(
    () => deriveWebSnapshots(inputs),
    new Error("Go flashcard IDs missing from generated flashcards: 999"),
  );
});

test("exporter check is read-only with snapshots and supports a web source override", (t) => {
  const cleanEnv = { ...process.env };
  delete cleanEnv.STAFF_DECK_WEB_ROOT;
  const trackedPaths = [
    path.join(nativeRoot, "Content", "base-flashcards.json"),
    path.join(nativeRoot, "Content", "base-practices.json"),
    path.join(nativeRoot, "StaffDeck", "Resources", "flashcards.json"),
    path.join(nativeRoot, "StaffDeck", "Resources", "practices.json"),
  ];
  const before = trackedPaths.map((filename) => ({
    contents: fs.readFileSync(filename),
    modifiedAt: fs.statSync(filename, { bigint: true }).mtimeNs,
  }));
  const assertTrackedFilesUnchanged = () => {
    trackedPaths.forEach((filename, index) => {
      assert.deepEqual(fs.readFileSync(filename), before[index].contents);
      assert.equal(fs.statSync(filename, { bigint: true }).mtimeNs, before[index].modifiedAt);
    });
  };
  const defaultResult = spawnSync(process.execPath, ["Scripts/export-content.mjs", "--check"], {
    cwd: nativeRoot,
    env: cleanEnv,
    encoding: "utf8",
  });
  assert.equal(defaultResult.status, 0, defaultResult.stderr);
  assert.match(defaultResult.stdout, /Verified 300 flashcards and 240 practices/);
  assertTrackedFilesUnchanged();

  const webRoot = fs.mkdtempSync(path.join(os.tmpdir(), "staff-deck-web-"));
  t.after(() => fs.rmSync(webRoot, { recursive: true, force: true }));
  const appRoot = path.join(webRoot, "app");
  fs.mkdirSync(appRoot);
  fs.writeFileSync(
    path.join(appRoot, "flashcards.ts"),
    `export const flashcards = ${readNative("Content/base-flashcards.json").trim()};\n`,
  );
  fs.writeFileSync(
    path.join(appRoot, "practice-data.ts"),
    `export const practices = ${readNative("Content/base-practices.json").trim()};\n`,
  );
  const overrideResult = spawnSync(process.execPath, ["Scripts/export-content.mjs", "--check"], {
    cwd: nativeRoot,
    env: { ...cleanEnv, STAFF_DECK_WEB_ROOT: webRoot },
    encoding: "utf8",
  });
  assert.equal(overrideResult.status, 0, overrideResult.stderr);
  assert.match(overrideResult.stdout, /Verified 300 flashcards and 240 practices/);
  assertTrackedFilesUnchanged();

  const changedBase = readNativeJson("Content/base-flashcards.json");
  changedBase.find((card) => card.id === 17).answer = "Changed external source answer";
  fs.writeFileSync(
    path.join(appRoot, "flashcards.ts"),
    `export const flashcards = ${serializeContent(changedBase).trim()};\n`,
  );
  const staleSnapshotResult = spawnSync(process.execPath, ["Scripts/export-content.mjs", "--check"], {
    cwd: nativeRoot,
    env: { ...cleanEnv, STAFF_DECK_WEB_ROOT: webRoot },
    encoding: "utf8",
  });
  assert.notEqual(staleSnapshotResult.status, 0);
  assert.match(staleSnapshotResult.stderr, /Content\/base-flashcards\.json/);
  assertTrackedFilesUnchanged();
});
