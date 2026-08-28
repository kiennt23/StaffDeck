import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildContent,
  extractArray,
  parseJson,
  serializeContent,
} from "./export-content-lib.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const nativeRoot = path.resolve(scriptDir, "..");
const webRoot = process.env.STAFF_DECK_WEB_ROOT;
const args = process.argv.slice(2);
const unknownArgs = args.filter((arg) => arg !== "--check");
const checkOnly = args.includes("--check");

if (unknownArgs.length > 0) {
  throw new Error(`Unknown argument: ${unknownArgs.join(", ")}`);
}

if (webRoot) {
  const missingSources = ["flashcards.ts", "practice-data.ts"].filter(
    (filename) => !fs.existsSync(path.join(webRoot, "app", filename)),
  );
  if (missingSources.length > 0) {
    throw new Error(
      `Cannot find ${missingSources.join(", ")} under ${webRoot}/app. Set STAFF_DECK_WEB_ROOT to the flashcards-app directory.`,
    );
  }
}

function readJson(relativePath) {
  return parseJson(
    fs.readFileSync(path.join(nativeRoot, relativePath), "utf8"),
    relativePath,
  );
}

function readWebArray(filename, exportName) {
  const source = fs.readFileSync(path.join(webRoot, "app", filename), "utf8");
  return extractArray(source, filename, exportName);
}

const webFlashcards = webRoot
  ? readWebArray("flashcards.ts", "flashcards")
  : readJson("Content/base-flashcards.json");
const webPractices = webRoot
  ? readWebArray("practice-data.ts", "practices")
  : readJson("Content/base-practices.json");

const { flashcards, practices } = buildContent({
  webFlashcards,
  additions: readJson("Content/java-fundamentals-additions.json"),
  fundamentalTopics: readJson("Content/java-fundamentals-topics.json"),
  goFlashcards: readJson("Content/go-cards.json"),
  answerOverrides: readJson("Content/flashcard-answer-overrides.json"),
  webPractices,
  goPractices: readJson("Content/go-practices.json"),
  practiceMetadata: readJson("Content/practice-metadata.json"),
});

const resources = path.join(nativeRoot, "StaffDeck", "Resources");
const resourceOutputs = [
  [path.join(resources, "flashcards.json"), serializeContent(flashcards)],
  [path.join(resources, "practices.json"), serializeContent(practices)],
];
const snapshotOutputs = webRoot
  ? [
      [path.join(nativeRoot, "Content", "base-flashcards.json"), serializeContent(webFlashcards)],
      [path.join(nativeRoot, "Content", "base-practices.json"), serializeContent(webPractices)],
    ]
  : [];
const outputs = [...snapshotOutputs, ...resourceOutputs];

if (checkOnly) {
  const changed = outputs
    .filter(([filename, content]) => !fs.existsSync(filename) || fs.readFileSync(filename, "utf8") !== content)
    .map(([filename]) => path.relative(nativeRoot, filename));
  if (changed.length > 0) {
    throw new Error(`Generated resources are out of date: ${changed.join(", ")}`);
  }
  console.log(`Verified ${flashcards.length} flashcards and ${practices.length} practices`);
  process.exit(0);
}

fs.mkdirSync(resources, { recursive: true });
for (const [filename, content] of outputs) fs.writeFileSync(filename, content);
console.log(`Exported ${flashcards.length} flashcards and ${practices.length} practices`);
