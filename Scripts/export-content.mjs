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

if (!webRoot) {
  throw new Error(
    "Set STAFF_DECK_WEB_ROOT to the Staff Deck web project before exporting content.",
  );
}

if (!fs.existsSync(path.join(webRoot, "app", "flashcards.ts"))) {
  throw new Error(
    `Cannot find the Staff Deck web source at ${webRoot}. Set STAFF_DECK_WEB_ROOT to the flashcards-app directory.`,
  );
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

const { flashcards, practices } = buildContent({
  webFlashcards: readWebArray("flashcards.ts", "flashcards"),
  additions: readJson("Content/java-fundamentals-additions.json"),
  fundamentalTopics: readJson("Content/java-fundamentals-topics.json"),
  goFlashcards: readJson("Content/go-cards.json"),
  answerOverrides: readJson("Content/flashcard-answer-overrides.json"),
  webPractices: readWebArray("practice-data.ts", "practices"),
  goPractices: readJson("Content/go-practices.json"),
});

const resources = path.join(nativeRoot, "StaffDeck", "Resources");
fs.mkdirSync(resources, { recursive: true });
fs.writeFileSync(path.join(resources, "flashcards.json"), serializeContent(flashcards));
fs.writeFileSync(path.join(resources, "practices.json"), serializeContent(practices));
console.log(`Exported ${flashcards.length} flashcards and ${practices.length} practices`);
