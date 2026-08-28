export const FILTER_SUBTOPICS = Object.freeze({
  "Memory & Synchronization": [9, 10, 11, 101],
  "Lifecycle & Cancellation": [13],
  "Capacity & Backpressure": [12, 14, 103],
  "Runtime Diagnostics": [15, 16, 102, 104],
  "HTTP, gRPC & API Design": [1, 2, 3, 7, 97, 99],
  "Contracts, Types & Data": [4, 5, 6, 98],
  "Clients, Timeouts & Retries": [100],
  "Service Testing": [8],
  "Modeling & Schema Evolution": [33, 38, 116],
  "Query Design & Indexing": [36, 113],
  "Transactions & Consistency": [34, 35, 37, 39],
  "Migrations, Rollouts & Diagnosis": [40, 114, 115],
  "Authentication, Authorization & Tenancy": [42, 43, 117, 119],
  "Secrets & Supply Chain": [44, 46, 120],
  "Input Validation & Data Exposure": [45, 118],
  "Auditability & Incident Response": [41, 47],
  "Security Guardrails & Rollout": [48],
  "SLOs, SLIs & Error Budgets": [57, 125],
  Observability: [58, 59],
  "Capacity, Overload & Backpressure": [60, 63, 64, 127],
  "Deployments & Rollbacks": [126, 128],
  "Incidents & Resilience Testing": [61, 62],
  "Containers, Kubernetes & Resource Limits": [51, 52, 53, 121, 122],
  "Networking & Service Connectivity": [124],
  "Configuration, Secrets & Environment Parity": [49, 50],
  "CI/CD, Progressive Delivery & Rollback": [54, 56, 123],
  "Platform Paved Roads & Adoption": [55],
});

export const PRODUCTION_RULES = Object.freeze({
  minimumWebFlashcards: 160,
  minimumAdditions: 21,
  minimumFundamentals: 41,
  minimumWebPractices: 208,
  expectedFlashcards: 300,
  expectedPractices: 240,
  goFlashcardStartID: 182,
  filterSubtopics: FILTER_SUBTOPICS,
});

export function parseJson(source, label) {
  try {
    return JSON.parse(source);
  } catch (error) {
    throw new Error(`Cannot parse ${label}: ${error.message}`, { cause: error });
  }
}

export function extractArray(source, filename, exportName) {
  const marker = `export const ${exportName}`;
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) throw new Error(`Cannot find ${marker} in ${filename}`);

  const assignment = source.indexOf("= [", markerIndex);
  const arrayStart = assignment < 0 ? -1 : assignment + 2;
  const arrayEnd = source.lastIndexOf("];");
  if (arrayStart < 0 || arrayEnd < arrayStart) {
    throw new Error(`Cannot extract ${exportName} from ${filename}`);
  }

  return parseJson(source.slice(arrayStart, arrayEnd + 1), `${exportName} from ${filename}`);
}

function createSubtopicMap(fundamentalTopics, filterSubtopics) {
  const subtopicByID = new Map();
  for (const [topic, cardIDs] of Object.entries(fundamentalTopics)) {
    for (const cardID of cardIDs) {
      if (subtopicByID.has(cardID)) {
        throw new Error(`Java Fundamentals card ${cardID} belongs to multiple subtopics`);
      }
      subtopicByID.set(cardID, topic);
    }
  }

  for (const [subtopic, cardIDs] of Object.entries(filterSubtopics)) {
    for (const cardID of cardIDs) {
      if (subtopicByID.has(cardID)) {
        throw new Error(`Flashcard ${cardID} belongs to multiple subtopics`);
      }
      subtopicByID.set(cardID, subtopic);
    }
  }
  return subtopicByID;
}

function validateBaseFlashcards(baseFlashcards, subtopicByID, rules) {
  const baseIDs = baseFlashcards.map((card) => card.id).sort((a, b) => a - b);
  if (baseIDs.some((id, index) => id !== index + 1)) {
    throw new Error(`Base flashcard IDs must represent 1 through ${baseIDs.length} exactly once`);
  }
  if (baseIDs[baseIDs.length - 1] >= rules.goFlashcardStartID) {
    throw new Error(
      `Base flashcard IDs must stay below ${rules.goFlashcardStartID}; Content/go-cards.json owns IDs ${rules.goFlashcardStartID}-${rules.expectedFlashcards}`,
    );
  }

  const fundamentals = baseFlashcards.filter((card) => card.topic === "Java Fundamentals");
  if (fundamentals.length < rules.minimumFundamentals) {
    throw new Error(
      `Expected at least ${rules.minimumFundamentals} Java Fundamentals cards, found ${fundamentals.length}`,
    );
  }
  if (fundamentals.some((card) => !card.subtopic)) {
    throw new Error("Every Java Fundamentals card must declare a subtopic");
  }

  const classified = baseFlashcards.filter((card) => card.subtopic);
  if (classified.length !== subtopicByID.size) {
    throw new Error(
      `Expected subtopic metadata for ${subtopicByID.size} flashcards, found ${classified.length}`,
    );
  }
}

export function buildContent(inputs, rules = PRODUCTION_RULES) {
  const {
    webFlashcards,
    additions,
    fundamentalTopics,
    goFlashcards,
    answerOverrides,
    webPractices,
    goPractices,
    practiceMetadata,
  } = inputs;

  if (webFlashcards.length < rules.minimumWebFlashcards) {
    throw new Error(
      `Expected at least ${rules.minimumWebFlashcards} web flashcards, found ${webFlashcards.length}`,
    );
  }
  if (additions.length < rules.minimumAdditions) {
    throw new Error(
      `Expected at least ${rules.minimumAdditions} native fundamentals additions, found ${additions.length}`,
    );
  }

  const webFundamentals = webFlashcards.filter((card) => card.topic === "Java Fundamentals");
  const webOtherTopics = webFlashcards.filter((card) => card.topic !== "Java Fundamentals");
  const subtopicByID = createSubtopicMap(fundamentalTopics, rules.filterSubtopics);
  const baseFlashcards = [...webFundamentals, ...additions, ...webOtherTopics].map((card) => {
    const subtopic = subtopicByID.get(card.id);
    if (!subtopic) return card;
    const { id, topic, subtopic: _snapshotSubtopic, ...content } = card;
    return { id, topic, subtopic, ...content };
  });

  const baseCardIDs = new Set(baseFlashcards.map((card) => String(card.id)));
  const missingOverrideIDs = Object.keys(answerOverrides).filter((id) => !baseCardIDs.has(id));
  if (missingOverrideIDs.length > 0) {
    throw new Error(`Answer overrides reference missing cards: ${missingOverrideIDs.join(", ")}`);
  }

  validateBaseFlashcards(baseFlashcards, subtopicByID, rules);
  if (webPractices.length < rules.minimumWebPractices) {
    throw new Error(
      `Expected at least ${rules.minimumWebPractices} web practices, found ${webPractices.length}`,
    );
  }

  const flashcards = [
    ...baseFlashcards.map((card) => ({
      ...card,
      answer: answerOverrides[String(card.id)] ?? card.answer,
    })),
    ...goFlashcards,
  ];
  const ids = flashcards.map((card) => card.id).sort((a, b) => a - b);
  if (
    ids.length !== rules.expectedFlashcards ||
    ids.some((id, index) => id !== index + 1)
  ) {
    throw new Error(
      `Merged flashcard IDs must represent 1 through ${rules.expectedFlashcards} exactly once`,
    );
  }

  const rawPractices = [...webPractices, ...goPractices];
  const practiceIDs = new Set(rawPractices.map((practice) => String(practice.id)));
  if (rawPractices.length !== rules.expectedPractices || practiceIDs.size !== rawPractices.length) {
    throw new Error(
      `Expected ${rules.expectedPractices} practices with unique IDs after merging Go content`,
    );
  }

  const practices = practiceMetadata
    ? rawPractices.map((practice) => {
        const meta = practiceMetadata[String(practice.id)];
        if (!meta) return practice;
        const {
          id,
          kind,
          contentTrack,
          competencyTopics: _oldTopics,
          rubricKind: _oldRubric,
          topic,
          week,
          number,
          title,
          prompt,
          artifact,
          followUps,
          completion,
          guide,
          modelAnswer,
          ...rest
        } = practice;
        return {
          id,
          kind,
          contentTrack,
          competencyTopics: meta.competencyTopics ?? [topic],
          rubricKind: meta.rubricKind ?? null,
          topic,
          week,
          number,
          title,
          prompt,
          artifact,
          followUps,
          completion,
          guide,
          modelAnswer,
          ...rest,
        };
      })
    : rawPractices;

  return { flashcards, practices };
}

export function serializeContent(content) {
  return `${JSON.stringify(content, null, 2)}\n`;
}
