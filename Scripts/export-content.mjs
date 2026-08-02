import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

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

function extractArray(filename, exportName) {
  const source = fs.readFileSync(path.join(webRoot, "app", filename), "utf8");
  const marker = `export const ${exportName}`;
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) throw new Error(`Cannot find ${marker} in ${filename}`);
  const assignment = source.indexOf("= [", markerIndex);
  const arrayStart = assignment < 0 ? -1 : assignment + 2;
  const arrayEnd = source.lastIndexOf("];");
  if (arrayStart < 0 || arrayEnd < arrayStart) {
    throw new Error(`Cannot extract ${exportName} from ${filename}`);
  }
  return JSON.parse(source.slice(arrayStart, arrayEnd + 1));
}

const flashcards = extractArray("flashcards.ts", "flashcards");
const practices = extractArray("practice-data.ts", "practices");

if (flashcards.length !== 160) {
  throw new Error(`Expected 160 flashcards, found ${flashcards.length}`);
}
const ids = flashcards.map((card) => card.id).sort((a, b) => a - b);
if (ids.some((id, index) => id !== index + 1)) {
  throw new Error("Flashcard IDs must represent 1 through 160 exactly once");
}
const fundamentals = flashcards.filter((card) => card.topic === "Java Fundamentals");
if (fundamentals.length !== 20) {
  throw new Error(`Expected 20 Java Fundamentals cards, found ${fundamentals.length}`);
}
if (practices.length !== 208) {
  throw new Error(`Expected 208 practices, found ${practices.length}`);
}

const resources = path.join(nativeRoot, "StaffDeck", "Resources");
fs.mkdirSync(resources, { recursive: true });
fs.writeFileSync(path.join(resources, "flashcards.json"), `${JSON.stringify(flashcards, null, 2)}\n`);
fs.writeFileSync(path.join(resources, "practices.json"), `${JSON.stringify(practices, null, 2)}\n`);
console.log(`Exported ${flashcards.length} flashcards and ${practices.length} practices`);
