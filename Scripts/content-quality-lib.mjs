const STOP_WORDS = new Set([
  "about",
  "after",
  "before",
  "does",
  "from",
  "have",
  "into",
  "should",
  "that",
  "their",
  "this",
  "what",
  "when",
  "where",
  "which",
  "with",
  "would",
]);

export function normalizeProse(value) {
  return value.toLowerCase().replaceAll(/[^a-z0-9]+/g, " ").trim();
}

export function exactDuplicateGroups(items, field) {
  const groups = new Map();
  for (const item of items) {
    const normalized = normalizeProse(item[field]);
    const ids = groups.get(normalized) ?? [];
    ids.push(item.id);
    groups.set(normalized, ids);
  }
  return [...groups.values()].filter((ids) => ids.length > 1);
}

function significantTerms(value) {
  return new Set(
    normalizeProse(value)
      .split(" ")
      .filter((term) => term.length > 3 && !STOP_WORDS.has(term)),
  );
}

function questionCoverage(card) {
  const terms = significantTerms(card.question);
  if (terms.size === 0) return 1;
  const answerTerms = significantTerms(card.answer);
  const covered = [...terms].filter((term) => answerTerms.has(term)).length;
  return covered / terms.size;
}

export function validateRewrittenCards(cards, rewrittenIDs) {
  const cardsByID = new Map(cards.map((card) => [card.id, card]));
  const allAnswers = exactDuplicateGroups(cards, "answer").flat();

  for (const id of rewrittenIDs) {
    const card = cardsByID.get(id);
    if (!card) throw new Error(`Rewritten card ${id} is missing`);
    if (allAnswers.includes(id)) throw new Error(`Rewritten card ${id} still has a duplicate answer`);
    if (card.answer.length < 600) {
      throw new Error(`Rewritten card ${id} answer must contain at least 600 characters`);
    }
    if (questionCoverage(card) < 0.4) {
      throw new Error(`Rewritten card ${id} answer does not cover enough question-specific terms`);
    }
    if (card.outline.length < 3 || card.outline.length > 8) {
      throw new Error(`Rewritten card ${id} outline must contain 3 to 8 points`);
    }
    if (card.followUps.length !== 3 || new Set(card.followUps).size !== 3) {
      throw new Error(`Rewritten card ${id} must contain exactly three distinct follow-ups`);
    }
    for (const field of ["testing", "example", "staffSignal"]) {
      if (card[field].length < 50) {
        throw new Error(`Rewritten card ${id} ${field} must contain at least 50 characters`);
      }
    }
    const supportingFields = [card.testing, card.example, card.staffSignal].map(normalizeProse);
    if (new Set(supportingFields).size !== supportingFields.length) {
      throw new Error(`Rewritten card ${id} supporting fields must be distinct`);
    }
  }
}
