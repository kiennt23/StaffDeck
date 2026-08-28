import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  buildContent,
  parseJson,
  serializeContent,
} from "./export-content-lib.mjs";
import { deriveWebSnapshots } from "./content-snapshot-lib.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const nativeRoot = path.resolve(scriptDir, "..");

function readJson(relativePath) {
  return parseJson(
    fs.readFileSync(path.join(nativeRoot, relativePath), "utf8"),
    relativePath,
  );
}

const flashcardResourcePath = "StaffDeck/Resources/flashcards.json";
const practiceResourcePath = "StaffDeck/Resources/practices.json";
const flashcardResource = fs.readFileSync(path.join(nativeRoot, flashcardResourcePath), "utf8");
const practiceResource = fs.readFileSync(path.join(nativeRoot, practiceResourcePath), "utf8");
const additions = readJson("Content/java-fundamentals-additions.json");
const goFlashcards = readJson("Content/go-cards.json");
const goPractices = readJson("Content/go-practices.json");

const { webFlashcards, webPractices } = deriveWebSnapshots({
  generatedFlashcards: parseJson(flashcardResource, flashcardResourcePath),
  additions,
  goFlashcards,
  generatedPractices: parseJson(practiceResource, practiceResourcePath),
  goPractices,
});

const rebuilt = buildContent({
  webFlashcards,
  additions,
  fundamentalTopics: readJson("Content/java-fundamentals-topics.json"),
  goFlashcards,
  answerOverrides: readJson("Content/flashcard-answer-overrides.json"),
  webPractices,
  goPractices,
  practiceMetadata: readJson("Content/practice-metadata.json"),
});
if (serializeContent(rebuilt.flashcards) !== flashcardResource) {
  throw new Error("Derived flashcard snapshot does not reproduce the tracked resource");
}
if (serializeContent(rebuilt.practices) !== practiceResource) {
  throw new Error("Derived practice snapshot does not reproduce the tracked resource");
}

fs.writeFileSync(
  path.join(nativeRoot, "Content", "base-flashcards.json"),
  serializeContent(webFlashcards),
);
fs.writeFileSync(
  path.join(nativeRoot, "Content", "base-practices.json"),
  serializeContent(webPractices),
);
console.log(
  `Derived ${webFlashcards.length} base flashcards and ${webPractices.length} base practices`,
);
