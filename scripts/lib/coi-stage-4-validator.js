"use strict";

const HARD_CODES = new Set([
  "DATE_INVERTED",
  "DATE_IMPLAUSIBLE",
  "LOW_CONFIDENCE",
  "NOT_A_COI",
  "OLDER_THAN_ON_FILE",
  "POSSIBLE_DUPLICATE_VENDOR",
  "PDF_PASSWORD_PROTECTED",
  "MODEL_REFUSED",
  "MODEL_OUTPUT_INVALID",
]);

const HIGH_RISK_TRADES = new Set([
  "electrical",
  "general contractor",
  "restoration",
  "roofing",
  "structural",
  "tree service",
]);

const VENDOR_STOP_TOKENS = new Set([
  "and",
  "co",
  "company",
  "corp",
  "corporation",
  "inc",
  "incorporated",
  "llc",
  "lp",
  "ltd",
  "pllc",
  "services",
  "service",
  "the",
]);

function normalizeNameForSql(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

function tokeniseName(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, " ")
    .trim()
    .split(/\s+/)
    .filter(Boolean)
    .filter((token) => !VENDOR_STOP_TOKENS.has(token));
}

function tokenSetRatio(left, right) {
  const leftTokens = new Set(tokeniseName(left));
  const rightTokens = new Set(tokeniseName(right));
  if (leftTokens.size === 0 || rightTokens.size === 0) {
    return 0;
  }

  let shared = 0;
  for (const token of leftTokens) {
    if (rightTokens.has(token)) {
      shared += 1;
    }
  }
  return (2 * shared) / (leftTokens.size + rightTokens.size);
}

function parseDate(value) {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(String(value))) {
    return null;
  }
  const [year, month, day] = String(value).split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (
    date.getUTCFullYear() !== year ||
    date.getUTCMonth() !== month - 1 ||
    date.getUTCDate() !== day
  ) {
    return null;
  }
  return date;
}

function formatDate(date) {
  if (!(date instanceof Date)) {
    return null;
  }
  return date.toISOString().slice(0, 10);
}

function addDays(date, days) {
  const copy = new Date(date.getTime());
  copy.setUTCDate(copy.getUTCDate() + days);
  return copy;
}

function compareDates(left, right) {
  const leftDate = parseDate(left);
  const rightDate = parseDate(right);
  if (!leftDate || !rightDate) {
    return null;
  }
  if (leftDate.getTime() === rightDate.getTime()) {
    return 0;
  }
  return leftDate.getTime() < rightDate.getTime() ? -1 : 1;
}

function daysBetween(left, right) {
  const leftDate = parseDate(left);
  const rightDate = parseDate(right);
  if (!leftDate || !rightDate) {
    return null;
  }
  return Math.round((rightDate.getTime() - leftDate.getTime()) / 86400000);
}

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function firstNonEmpty(...values) {
  for (const value of values) {
    if (value !== null && value !== undefined && String(value).trim() !== "") {
      return value;
    }
  }
  return null;
}

function makeFlag(code, severity, message, details = {}) {
  return { code, severity, message, details };
}

function addFlag(flags, code, severity, message, details = {}) {
  if (!flags.some((flag) => flag.code === code && JSON.stringify(flag.details) === JSON.stringify(details))) {
    flags.push(makeFlag(code, severity, message, details));
  }
}

function normalizeCoverage(coverage) {
  return {
    coverage_type: firstNonEmpty(coverage.coverage_type, coverage.type),
    insurer_name: coverage.insurer_name ?? null,
    naic: coverage.naic ?? null,
    policy_number: coverage.policy_number ?? null,
    effective_date: coverage.effective_date ?? null,
    expiration_date: coverage.expiration_date ?? null,
    each_occurrence:
      coverage.each_occurrence === null || coverage.each_occurrence === undefined
        ? null
        : Number(coverage.each_occurrence),
    general_aggregate:
      coverage.general_aggregate === null || coverage.general_aggregate === undefined
        ? null
        : Number(coverage.general_aggregate),
    addl_insd_asserted: Boolean(coverage.addl_insd_asserted),
    subr_wvd_asserted: Boolean(coverage.subr_wvd_asserted),
  };
}

function normalizeExtractionShape(extraction) {
  const source = extraction && typeof extraction === "object" ? extraction : {};
  return {
    is_certificate_of_insurance: Boolean(source.is_certificate_of_insurance),
    vendor_legal_name: source.vendor_legal_name ?? null,
    vendor_address: source.vendor_address ?? null,
    producer_name: source.producer_name ?? null,
    producer_email: source.producer_email ?? null,
    producer_phone: source.producer_phone ?? null,
    certificate_date: source.certificate_date ?? null,
    certificate_holder: source.certificate_holder ?? null,
    coverages: safeArray(source.coverages).map(normalizeCoverage),
    description_of_operations: source.description_of_operations ?? null,
    cancellation_notice_wording: source.cancellation_notice_wording ?? null,
    extraction_confidence: source.extraction_confidence ?? null,
    confidence_reason: source.confidence_reason ?? null,
  };
}

function parsePossibleJson(value) {
  if (value && typeof value === "object") {
    return { ok: true, value };
  }
  if (typeof value !== "string") {
    return { ok: false, reason: "Model output was not JSON text." };
  }

  const trimmed = value.trim();
  if (!trimmed) {
    return { ok: false, reason: "Model output was empty." };
  }

  try {
    return { ok: true, value: JSON.parse(trimmed) };
  } catch (error) {
    return { ok: false, reason: error.message };
  }
}

function findRefusal(raw) {
  if (!raw || typeof raw !== "object") {
    return null;
  }

  const candidates = [
    raw.refusal,
    raw.message && raw.message.refusal,
    raw.output && raw.output.refusal,
    raw.choices && raw.choices[0] && raw.choices[0].message && raw.choices[0].message.refusal,
  ];

  for (const candidate of candidates) {
    if (candidate) {
      return typeof candidate === "string" ? candidate : JSON.stringify(candidate);
    }
  }
  return null;
}

function extractModelContent(raw) {
  if (!raw || typeof raw !== "object") {
    return raw;
  }

  if (raw.output && Array.isArray(raw.output)) {
    const contentValues = raw.output
      .flatMap((entry) => safeArray(entry.content))
      .map((entry) => entry.text || entry.output_text || "")
      .filter(Boolean);
    if (contentValues.length === 1 && typeof contentValues[0] === "object") {
      return contentValues[0];
    }
    const text = contentValues.join("");
    if (text) {
      return text;
    }
  }

  const direct = firstNonEmpty(raw.output, raw.json, raw.text, raw.content, raw.response, raw.result);
  if (direct) {
    return direct;
  }

  if (raw.choices && raw.choices[0] && raw.choices[0].message) {
    return raw.choices[0].message.content;
  }

  return raw;
}

function normalizeModelOutput(raw) {
  const refusal = findRefusal(raw);
  if (refusal) {
    return {
      ok: false,
      flag: makeFlag("MODEL_REFUSED", "hard", "The model refused to process the document.", { refusal }),
    };
  }

  const content = extractModelContent(raw);
  const parsed = parsePossibleJson(content);
  if (!parsed.ok) {
    return {
      ok: false,
      flag: makeFlag("MODEL_OUTPUT_INVALID", "hard", "The model output could not be parsed as JSON.", {
        reason: parsed.reason,
      }),
    };
  }

  return { ok: true, extraction: normalizeExtractionShape(parsed.value) };
}

function findVendorMatch(vendorName, vendors) {
  const normalized = normalizeNameForSql(vendorName);
  const exact = safeArray(vendors).find((vendor) => vendor.normalised_name === normalized);
  if (exact) {
    return {
      match_type: "exact",
      score: 1,
      vendor: exact,
      normalized_name: normalized,
    };
  }

  let best = null;
  for (const vendor of safeArray(vendors)) {
    const score = tokenSetRatio(vendorName, vendor.legal_name);
    if (!best || score > best.score) {
      best = { match_type: "none", score, vendor, normalized_name: normalized };
    }
  }

  if (best && best.score >= 0.8 && best.score <= 0.94) {
    best.match_type = "near";
    return best;
  }

  return {
    match_type: "none",
    score: best ? best.score : 0,
    vendor: null,
    normalized_name: normalized,
  };
}

function findHolderMatch(holderName, holderEntities) {
  let best = null;
  for (const holder of safeArray(holderEntities)) {
    const score = tokenSetRatio(holderName, holder.legal_name);
    if (!best || score > best.score) {
      best = { legal_name: holder.legal_name, score };
    }
  }
  return {
    matched: Boolean(best && best.score >= 0.8),
    best_match: best ? best.legal_name : null,
    score: best ? best.score : 0,
  };
}

function findRequirement(trade, requirements) {
  const all = safeArray(requirements);
  const exact = all.find((item) => String(item.trade || "").toLowerCase() === String(trade || "").toLowerCase());
  const fallback = all.find((item) => String(item.trade || "").toUpperCase() === "DEFAULT");
  return exact || fallback || {
    trade: "DEFAULT",
    min_each_occurrence: 1000000,
    min_general_aggregate: 2000000,
    wc_required: true,
  };
}

function getGlCoverage(coverages) {
  return safeArray(coverages).find((coverage) => coverage.coverage_type === "GENERAL_LIABILITY") || null;
}

function getPreviousGlCoverage(vendor) {
  const previous = safeArray(vendor && vendor.current_coverages);
  return previous.find((coverage) => coverage.coverage_type === "GENERAL_LIABILITY") || null;
}

function validateDateFields(extraction, flags) {
  const certificateDate = parseDate(extraction.certificate_date);
  const anchor = certificateDate || parseDate(extraction.received_at) || new Date();
  const minDate = addDays(anchor, -730);
  const maxDate = addDays(anchor, 1095);
  const dateFields = [];

  if (extraction.certificate_date !== null && !certificateDate) {
    addFlag(flags, "DATE_IMPLAUSIBLE", "hard", "The certificate date is not a valid YYYY-MM-DD date.", {
      field: "certificate_date",
      value: extraction.certificate_date,
    });
  }

  for (const [index, coverage] of extraction.coverages.entries()) {
    dateFields.push(["effective_date", coverage.effective_date, index]);
    dateFields.push(["expiration_date", coverage.expiration_date, index]);

    const effective = parseDate(coverage.effective_date);
    const expiration = parseDate(coverage.expiration_date);
    if (coverage.effective_date !== null && !effective) {
      addFlag(flags, "DATE_IMPLAUSIBLE", "hard", "A coverage effective date is invalid.", {
        coverage_index: index,
        field: "effective_date",
        value: coverage.effective_date,
      });
    }
    if (coverage.expiration_date !== null && !expiration) {
      addFlag(flags, "DATE_IMPLAUSIBLE", "hard", "A coverage expiration date is invalid.", {
        coverage_index: index,
        field: "expiration_date",
        value: coverage.expiration_date,
      });
    }
    if (effective && expiration && expiration.getTime() <= effective.getTime()) {
      addFlag(flags, "DATE_INVERTED", "hard", "A coverage expiration date is not after its effective date.", {
        coverage_index: index,
        coverage_type: coverage.coverage_type,
        effective_date: coverage.effective_date,
        expiration_date: coverage.expiration_date,
      });
    }
  }

  for (const [field, value, coverageIndex] of dateFields) {
    const parsed = parseDate(value);
    if (!parsed) {
      if (value === null || value === undefined || value === "") {
        addFlag(flags, "DATE_IMPLAUSIBLE", "hard", "A coverage date is missing.", {
          coverage_index: coverageIndex,
          field,
        });
      }
      continue;
    }
    if (parsed.getTime() < minDate.getTime() || parsed.getTime() > maxDate.getTime()) {
      addFlag(flags, "DATE_IMPLAUSIBLE", "hard", "A coverage date falls outside the expected range.", {
        coverage_index: coverageIndex,
        field,
        value,
        min_date: formatDate(minDate),
        max_date: formatDate(maxDate),
      });
    }
  }
}

function validateExtraction(extractionInput, contextInput = {}) {
  const context = contextInput || {};
  const flags = [];
  const extractionMethod = context.extraction_method || null;

  if (context.pdf_error === "PDF_PASSWORD_PROTECTED") {
    addFlag(flags, "PDF_PASSWORD_PROTECTED", "hard", "The PDF requires a password before it can be read.", {
      fixture_id: context.fixture_id || null,
    });
    return buildResult(null, context, flags, null, null, extractionMethod);
  }

  const normalizedFromModel = normalizeModelOutput(extractionInput);
  if (!normalizedFromModel.ok) {
    flags.push(normalizedFromModel.flag);
    return buildResult(null, context, flags, null, null, extractionMethod);
  }

  const extraction = normalizedFromModel.extraction;

  if (!extraction.is_certificate_of_insurance) {
    addFlag(flags, "NOT_A_COI", "hard", "The document is not a certificate of liability insurance.", {});
    return buildResult(extraction, context, flags, null, null, extractionMethod);
  }

  if (extraction.extraction_confidence === "LOW") {
    addFlag(flags, "LOW_CONFIDENCE", "hard", "The model marked this extraction as low confidence.", {
      reason: extraction.confidence_reason || null,
    });
  }

  validateDateFields(extraction, flags);

  const vendorMatch = findVendorMatch(extraction.vendor_legal_name, context.vendors);
  if (vendorMatch.match_type === "near") {
    addFlag(flags, "POSSIBLE_DUPLICATE_VENDOR", "hard", "The vendor name is close to an existing vendor and needs human review.", {
      extracted_vendor_name: extraction.vendor_legal_name,
      near_match_vendor_name: vendorMatch.vendor.legal_name,
      score: Number(vendorMatch.score.toFixed(3)),
    });
  }

  const holderMatch = findHolderMatch(extraction.certificate_holder, context.holder_entities);
  if (!holderMatch.matched) {
    addFlag(flags, "HOLDER_MISMATCH", "soft", "The certificate holder does not match an accepted holder entity.", {
      certificate_holder: extraction.certificate_holder,
      best_match: holderMatch.best_match,
      score: Number(holderMatch.score.toFixed(3)),
    });
  }

  const matchedVendor = vendorMatch.vendor;
  const trade = matchedVendor && matchedVendor.trade ? matchedVendor.trade : context.default_trade;
  const requirement = findRequirement(trade, context.trade_requirements);
  const glCoverage = getGlCoverage(extraction.coverages);

  if (!glCoverage) {
    addFlag(flags, "NO_GL_LINE", "soft", "No general liability line was found on the document.", {});
  } else {
    if (
      requirement.min_each_occurrence !== null &&
      requirement.min_each_occurrence !== undefined &&
      (glCoverage.each_occurrence === null || glCoverage.each_occurrence < Number(requirement.min_each_occurrence))
    ) {
      addFlag(flags, "LIMIT_BELOW_MINIMUM", "soft", "The general liability each-occurrence limit is below the configured requirement.", {
        coverage_type: "GENERAL_LIABILITY",
        field: "each_occurrence",
        actual: glCoverage.each_occurrence,
        minimum: Number(requirement.min_each_occurrence),
        requirement_trade: requirement.trade,
      });
    }
    if (
      requirement.min_general_aggregate !== null &&
      requirement.min_general_aggregate !== undefined &&
      (glCoverage.general_aggregate === null || glCoverage.general_aggregate < Number(requirement.min_general_aggregate))
    ) {
      addFlag(flags, "LIMIT_BELOW_MINIMUM", "soft", "The general liability aggregate limit is below the configured requirement.", {
        coverage_type: "GENERAL_LIABILITY",
        field: "general_aggregate",
        actual: glCoverage.general_aggregate,
        minimum: Number(requirement.min_general_aggregate),
        requirement_trade: requirement.trade,
      });
    }
  }

  const wcRequired = requirement.wc_required !== false;
  const wcExempt = Boolean(matchedVendor && matchedVendor.wc_exempt);
  const hasWorkersComp = extraction.coverages.some((coverage) => coverage.coverage_type === "WORKERS_COMP");
  if (wcRequired && !wcExempt && !hasWorkersComp) {
    addFlag(flags, "NO_WC_LINE", "soft", "No workers compensation line was found for a vendor that is not marked exempt.", {
      requirement_trade: requirement.trade,
    });
  }

  if (matchedVendor && matchedVendor.current_certificate_date && extraction.certificate_date) {
    const order = compareDates(extraction.certificate_date, matchedVendor.current_certificate_date);
    if (order === -1) {
      addFlag(flags, "OLDER_THAN_ON_FILE", "hard", "The certificate date is older than the active certificate already on file.", {
        current_certificate_date: matchedVendor.current_certificate_date,
        new_certificate_date: extraction.certificate_date,
      });
    }
  }

  const previousGl = getPreviousGlCoverage(matchedVendor);
  if (previousGl && glCoverage && previousGl.expiration_date && glCoverage.effective_date) {
    const gapDays = daysBetween(previousGl.expiration_date, glCoverage.effective_date);
    if (gapDays !== null && gapDays > 0) {
      addFlag(flags, "COVERAGE_GAP", "soft", "The replacement general liability policy starts after the prior policy ended.", {
        gap_days: gapDays,
        previous_expiration_date: previousGl.expiration_date,
        new_effective_date: glCoverage.effective_date,
      });
    }
  }

  const highRisk = HIGH_RISK_TRADES.has(String(trade || "").toLowerCase());
  if (highRisk && !extraction.cancellation_notice_wording) {
    addFlag(flags, "NO_CANCELLATION_NOTICE_WORDING", "note", "No cancellation-notice wording was found for this high-risk trade.", {
      trade,
    });
  }

  return buildResult(extraction, context, flags, vendorMatch, holderMatch, extractionMethod);
}

function buildResult(extraction, context, flags, vendorMatch, holderMatch, extractionMethod) {
  const hardFlags = flags.filter((flag) => HARD_CODES.has(flag.code));
  let disposition = "store_on_file";
  let status = "ON_FILE";

  if (flags.some((flag) => flag.code === "NOT_A_COI")) {
    disposition = "ignore_not_certificate";
    status = null;
  } else if (flags.some((flag) => flag.code === "OLDER_THAN_ON_FILE")) {
    disposition = "ignore_older_than_on_file";
    status = null;
  } else if (hardFlags.length > 0) {
    disposition = "store_needs_review";
    status = "NEEDS_REVIEW";
  }

  const certificate = extraction ? {
    source: context.source || null,
    source_ref: context.fixture_id || context.source_ref || null,
    original_filename: context.original_filename || null,
    stored_path: context.stored_path || null,
    certificate_date: extraction.certificate_date,
    certificate_holder: extraction.certificate_holder,
    holder_match: holderMatch ? holderMatch.matched : null,
    extraction_confidence: extraction.extraction_confidence,
    extraction_method: extractionMethod,
    raw_extraction: extraction,
    validation_flags: flags,
    status,
    cancellation_notice_wording: extraction.cancellation_notice_wording,
  } : {
    source: context.source || null,
    source_ref: context.fixture_id || context.source_ref || null,
    original_filename: context.original_filename || null,
    stored_path: context.stored_path || null,
    certificate_date: null,
    certificate_holder: null,
    holder_match: null,
    extraction_confidence: "LOW",
    extraction_method: extractionMethod,
    raw_extraction: null,
    validation_flags: flags,
    status,
    cancellation_notice_wording: null,
  };

  return {
    fixture_id: context.fixture_id || null,
    disposition,
    status,
    extraction_method: extractionMethod,
    vendor_match: vendorMatch ? {
      match_type: vendorMatch.match_type,
      score: Number(vendorMatch.score.toFixed(3)),
      vendor_id: vendorMatch.vendor ? vendorMatch.vendor.id ?? null : null,
      vendor_legal_name: vendorMatch.vendor ? vendorMatch.vendor.legal_name : null,
      normalized_name: vendorMatch.normalized_name,
    } : null,
    holder_match: holderMatch || null,
    validation_flags: flags,
    certificate,
    coverages: extraction ? extraction.coverages : [],
    raw_extraction: extraction,
  };
}

module.exports = {
  HARD_CODES,
  normalizeNameForSql,
  normalizeModelOutput,
  tokenSetRatio,
  validateExtraction,
};
