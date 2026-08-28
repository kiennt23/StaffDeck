export const SNAPSHOT_RULES = Object.freeze({
  expectedWebFlashcards: 160,
  expectedWebPractices: 208,
  expectedFlashcards: 300,
  expectedPractices: 240,
});

function collectIDs(items, label) {
  const ids = new Set();
  for (const item of items) {
    const key = String(item.id);
    if (ids.has(key)) throw new Error(`Duplicate ${label} ID: ${item.id}`);
    ids.add(key);
  }
  return ids;
}

function missingIDs(ids, container) {
  return [...ids].filter((id) => !container.has(id));
}

export function deriveWebSnapshots(inputs, rules = SNAPSHOT_RULES) {
  const {
    generatedFlashcards,
    additions,
    goFlashcards,
    generatedPractices,
    goPractices,
  } = inputs;

  const generatedCardIDs = collectIDs(generatedFlashcards, "generated flashcard");
  if (generatedFlashcards.length !== rules.expectedFlashcards) {
    throw new Error(
      `Expected ${rules.expectedFlashcards} generated flashcards, found ${generatedFlashcards.length}`,
    );
  }

  const additionIDs = collectIDs(additions, "Java fundamentals addition");
  const goCardIDs = collectIDs(goFlashcards, "Go flashcard");
  const sharedCardIDs = [...additionIDs].filter((id) => goCardIDs.has(id));
  if (sharedCardIDs.length > 0) {
    throw new Error(
      `Flashcard IDs owned by both Java additions and Go content: ${sharedCardIDs.join(", ")}`,
    );
  }

  const unknownAdditions = missingIDs(additionIDs, generatedCardIDs);
  if (unknownAdditions.length > 0) {
    throw new Error(
      `Java fundamentals addition IDs missing from generated flashcards: ${unknownAdditions.join(", ")}`,
    );
  }
  const unknownGoCards = missingIDs(goCardIDs, generatedCardIDs);
  if (unknownGoCards.length > 0) {
    throw new Error(
      `Go flashcard IDs missing from generated flashcards: ${unknownGoCards.join(", ")}`,
    );
  }

  const webFlashcards = generatedFlashcards.filter(
    (card) => !additionIDs.has(String(card.id)) && !goCardIDs.has(String(card.id)),
  );
  if (webFlashcards.length + additions.length + goFlashcards.length !== generatedFlashcards.length) {
    throw new Error(
      `Web snapshot, Java additions, and Go cards must reconstruct ${generatedFlashcards.length} generated flashcards exactly`,
    );
  }
  if (webFlashcards.length !== rules.expectedWebFlashcards) {
    throw new Error(
      `Expected ${rules.expectedWebFlashcards} web snapshot flashcards, found ${webFlashcards.length}`,
    );
  }

  const generatedPracticeIDs = collectIDs(generatedPractices, "generated practice");
  if (generatedPractices.length !== rules.expectedPractices) {
    throw new Error(
      `Expected ${rules.expectedPractices} generated practices, found ${generatedPractices.length}`,
    );
  }
  const goPracticeIDs = collectIDs(goPractices, "Go practice");
  const unknownGoPractices = missingIDs(goPracticeIDs, generatedPracticeIDs);
  if (unknownGoPractices.length > 0) {
    throw new Error(
      `Go practice IDs missing from generated practices: ${unknownGoPractices.join(", ")}`,
    );
  }

  const webPractices = generatedPractices
    .filter((practice) => !goPracticeIDs.has(String(practice.id)))
    .map((practice) => {
      const { competencyTopics, rubricKind, ...rest } = practice;
      return rest;
    });
  if (webPractices.length + goPractices.length !== generatedPractices.length) {
    throw new Error(
      `Web snapshot and Go practices must reconstruct ${generatedPractices.length} generated practices exactly`,
    );
  }
  if (webPractices.length !== rules.expectedWebPractices) {
    throw new Error(
      `Expected ${rules.expectedWebPractices} web snapshot practices, found ${webPractices.length}`,
    );
  }

  return { webFlashcards, webPractices };
}
