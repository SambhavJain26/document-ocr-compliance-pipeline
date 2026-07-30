"use strict";

const assert = require("node:assert/strict");
const {
  normalizeModelOutput,
  tokenSetRatio,
  validateExtraction,
} = require("./lib/coi-stage-4-validator");

function baseContext(overrides = {}) {
  return {
    fixture_id: "unit-test",
    source: "form",
    extraction_method: "text",
    holder_entities: [
      { legal_name: "Harbourline Property Management LLC" },
      { legal_name: "Harbourline Oakview Owner LLC" },
      { legal_name: "Harbourline Cedar Flats LLC" },
    ],
    trade_requirements: [
      { trade: "DEFAULT", min_each_occurrence: 1000000, min_general_aggregate: 2000000, wc_required: true },
      { trade: "Roofing", min_each_occurrence: 2000000, min_general_aggregate: 4000000, wc_required: true },
      { trade: "Landscaping", min_each_occurrence: 500000, min_general_aggregate: 1000000, wc_required: true },
    ],
    vendors: [
      {
        id: 1,
        legal_name: "Apex Plumbing Services LLC",
        normalised_name: "apex-plumbing-services-llc",
        trade: "Plumbing",
        wc_exempt: false,
        current_certificate_date: "2026-07-30",
        current_coverages: [
          { coverage_type: "GENERAL_LIABILITY", expiration_date: "2027-03-30" },
        ],
      },
      {
        id: 2,
        legal_name: "Blue Ridge HVAC Co.",
        normalised_name: "blue-ridge-hvac-co",
        trade: "HVAC",
        wc_exempt: false,
        current_certificate_date: "2026-08-10",
        current_coverages: [
          { coverage_type: "GENERAL_LIABILITY", expiration_date: "2026-08-19" },
        ],
      },
      {
        id: 3,
        legal_name: "Circuit Square Electric LLC",
        normalised_name: "circuit-square-electric-llc",
        trade: "Electrical",
        wc_exempt: false,
        current_certificate_date: "2025-06-20",
        current_coverages: [
          { coverage_type: "GENERAL_LIABILITY", expiration_date: "2026-03-01" },
        ],
      },
      {
        id: 4,
        legal_name: "Mason Creek Handyman",
        normalised_name: "mason-creek-handyman",
        trade: "General Contractor",
        wc_exempt: true,
        current_certificate_date: null,
        current_coverages: [],
      },
      {
        id: 5,
        legal_name: "Summit Shield Roofing Inc.",
        normalised_name: "summit-shield-roofing-inc",
        trade: "Roofing",
        wc_exempt: false,
        current_certificate_date: null,
        current_coverages: [],
      },
    ],
    ...overrides,
  };
}

function sampleExtraction(overrides = {}) {
  return {
    is_certificate_of_insurance: true,
    vendor_legal_name: "Apex Plumbing Services LLC",
    vendor_address: "100 Example Way",
    producer_name: "Northgate Risk Partners",
    producer_email: "certs+northgate@example.test",
    producer_phone: "555-0101",
    certificate_date: "2026-07-30",
    certificate_holder: "Harbourline Property Management LLC",
    coverages: [
      {
        type: "GENERAL_LIABILITY",
        insurer_name: "Northgate Mutual",
        naic: null,
        policy_number: "NMG-1001-GL",
        effective_date: "2026-07-01",
        expiration_date: "2027-03-30",
        each_occurrence: 1000000,
        general_aggregate: 2000000,
        addl_insd_asserted: true,
        subr_wvd_asserted: false,
      },
      {
        type: "WORKERS_COMP",
        insurer_name: "Ironvale Indemnity",
        naic: null,
        policy_number: "IRN-1001-WC",
        effective_date: "2026-07-01",
        expiration_date: "2027-03-30",
        each_occurrence: 500000,
        general_aggregate: null,
        addl_insd_asserted: false,
        subr_wvd_asserted: false,
      },
    ],
    description_of_operations: "Routine certificate paperwork.",
    cancellation_notice_wording: null,
    extraction_confidence: "HIGH",
    confidence_reason: null,
    ...overrides,
  };
}

function validate(extractionOverrides = {}, contextOverrides = {}) {
  return validateExtraction(sampleExtraction(extractionOverrides), baseContext(contextOverrides));
}

function codes(result) {
  return result.validation_flags.map((flag) => flag.code);
}

function assertHasCode(result, code) {
  assert.ok(codes(result).includes(code), `Expected ${code}, got ${codes(result).join(", ")}`);
}

function assertNoCode(result, code) {
  assert.ok(!codes(result).includes(code), `Did not expect ${code}, got ${codes(result).join(", ")}`);
}

function run(name, fn) {
  fn();
  console.log(`ok - ${name}`);
}

run("happy path stores ON_FILE", () => {
  const result = validate();
  assert.equal(result.disposition, "store_on_file");
  assert.equal(result.status, "ON_FILE");
  assert.equal(result.vendor_match.match_type, "exact");
  assert.equal(result.certificate.raw_extraction.coverages[0].addl_insd_asserted, true);
});

run("model output parser handles object and string outputs", () => {
  assert.equal(normalizeModelOutput(sampleExtraction()).ok, true);
  assert.equal(normalizeModelOutput(JSON.stringify(sampleExtraction())).ok, true);
  assert.equal(normalizeModelOutput({ output: sampleExtraction() }).ok, true);
});

run("model refusal becomes hard flag", () => {
  const result = validateExtraction({ choices: [{ message: { refusal: "no" } }] }, baseContext());
  assertHasCode(result, "MODEL_REFUSED");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("invalid model output becomes hard flag", () => {
  const result = validateExtraction("not json", baseContext());
  assertHasCode(result, "MODEL_OUTPUT_INVALID");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("password PDF error is graceful", () => {
  const result = validateExtraction(null, baseContext({ pdf_error: "PDF_PASSWORD_PROTECTED" }));
  assertHasCode(result, "PDF_PASSWORD_PROTECTED");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("not a COI is ignored", () => {
  const result = validate({
    is_certificate_of_insurance: false,
    vendor_legal_name: null,
    certificate_holder: null,
    coverages: [],
  });
  assertHasCode(result, "NOT_A_COI");
  assert.equal(result.disposition, "ignore_not_certificate");
  assert.equal(result.status, null);
});

run("date inversion forces review", () => {
  const result = validate({
    coverages: [
      {
        type: "GENERAL_LIABILITY",
        insurer_name: "Northgate Mutual",
        naic: null,
        policy_number: "NMG-1001-GL",
        effective_date: "2026-09-01",
        expiration_date: "2026-08-01",
        each_occurrence: 1000000,
        general_aggregate: 2000000,
        addl_insd_asserted: true,
        subr_wvd_asserted: false,
      },
    ],
  });
  assertHasCode(result, "DATE_INVERTED");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("invalid and implausible dates force review", () => {
  const invalid = validate({ certificate_date: "2026-13-01" });
  assertHasCode(invalid, "DATE_IMPLAUSIBLE");
  const outOfRange = validate({
    coverages: [
      {
        type: "GENERAL_LIABILITY",
        insurer_name: "Northgate Mutual",
        naic: null,
        policy_number: "NMG-1001-GL",
        effective_date: "2021-01-01",
        expiration_date: "2021-12-31",
        each_occurrence: 1000000,
        general_aggregate: 2000000,
        addl_insd_asserted: true,
        subr_wvd_asserted: false,
      },
    ],
  });
  assertHasCode(outOfRange, "DATE_IMPLAUSIBLE");
});

run("low confidence forces review", () => {
  const result = validate({ extraction_confidence: "LOW", confidence_reason: "scan is unclear" });
  assertHasCode(result, "LOW_CONFIDENCE");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("missing GL is a soft flag", () => {
  const result = validate({
    vendor_legal_name: "Prime Coat Painting LLC",
    coverages: [
      {
        type: "WORKERS_COMP",
        insurer_name: "Ironvale Indemnity",
        naic: null,
        policy_number: "IRN-9009-WC",
        effective_date: "2026-02-01",
        expiration_date: "2027-02-01",
        each_occurrence: 500000,
        general_aggregate: null,
        addl_insd_asserted: false,
        subr_wvd_asserted: false,
      },
    ],
  });
  assertHasCode(result, "NO_GL_LINE");
  assert.equal(result.status, "ON_FILE");
});

run("missing WC is soft unless vendor is exempt", () => {
  const missing = validate({
    vendor_legal_name: "Apex Plumbing Services LLC",
    coverages: [sampleExtraction().coverages[0]],
  });
  assertHasCode(missing, "NO_WC_LINE");

  const exempt = validate({
    vendor_legal_name: "Mason Creek Handyman",
    coverages: [sampleExtraction().coverages[0]],
  });
  assertNoCode(exempt, "NO_WC_LINE");
});

run("holder mismatch is soft", () => {
  const result = validate({ certificate_holder: "Beacon Ridge Realty" });
  assertHasCode(result, "HOLDER_MISMATCH");
  assert.equal(result.status, "ON_FILE");
});

run("accepted owner LLC holder passes", () => {
  const result = validate({ certificate_holder: "Harbourline Oakview Owner LLC" });
  assertNoCode(result, "HOLDER_MISMATCH");
});

run("trade-specific low limits are soft", () => {
  const result = validate({
    vendor_legal_name: "Summit Shield Roofing Inc.",
    coverages: [
      {
        type: "GENERAL_LIABILITY",
        insurer_name: "Northgate Mutual",
        naic: null,
        policy_number: "NMG-5005-GL",
        effective_date: "2026-07-01",
        expiration_date: "2027-07-01",
        each_occurrence: 1000000,
        general_aggregate: 2000000,
        addl_insd_asserted: true,
        subr_wvd_asserted: false,
      },
      sampleExtraction().coverages[1],
    ],
  });
  assertHasCode(result, "LIMIT_BELOW_MINIMUM");
  assert.equal(result.status, "ON_FILE");
});

run("older than on file is ignored", () => {
  const result = validate({
    vendor_legal_name: "Blue Ridge HVAC Co.",
    certificate_date: "2026-07-30",
  });
  assertHasCode(result, "OLDER_THAN_ON_FILE");
  assert.equal(result.disposition, "ignore_older_than_on_file");
  assert.equal(result.status, null);
});

run("coverage gap stores gap day count", () => {
  const result = validate({
    vendor_legal_name: "Circuit Square Electric LLC",
    certificate_date: "2026-03-16",
    coverages: [
      {
        type: "GENERAL_LIABILITY",
        insurer_name: "Ironvale Indemnity",
        naic: null,
        policy_number: "IRN-3013-GL",
        effective_date: "2026-03-15",
        expiration_date: "2027-03-15",
        each_occurrence: 1000000,
        general_aggregate: 2000000,
        addl_insd_asserted: true,
        subr_wvd_asserted: true,
      },
      sampleExtraction().coverages[1],
    ],
  });
  assertHasCode(result, "COVERAGE_GAP");
  assert.equal(result.validation_flags.find((flag) => flag.code === "COVERAGE_GAP").details.gap_days, 14);
});

run("near duplicate vendor forces review", () => {
  const score = tokenSetRatio("Apex Plumbing and Heating LLC", "Apex Plumbing Services LLC");
  assert.ok(score >= 0.8 && score <= 0.94, score);
  const result = validate({ vendor_legal_name: "Apex Plumbing and Heating LLC" });
  assertHasCode(result, "POSSIBLE_DUPLICATE_VENDOR");
  assert.equal(result.status, "NEEDS_REVIEW");
});

run("high-risk missing cancellation wording is a note", () => {
  const result = validate({ vendor_legal_name: "Summit Shield Roofing Inc." });
  assertHasCode(result, "NO_CANCELLATION_NOTICE_WORDING");
  assert.equal(result.validation_flags.find((flag) => flag.code === "NO_CANCELLATION_NOTICE_WORDING").severity, "note");
  assert.equal(result.status, "ON_FILE");
});

run("cancellation wording is retained as neutral fact", () => {
  const wording = "Thirty days written notice of cancellation will be sent to the certificate holder when required by policy terms.";
  const result = validate({ vendor_legal_name: "Summit Shield Roofing Inc.", cancellation_notice_wording: wording });
  assertNoCode(result, "NO_CANCELLATION_NOTICE_WORDING");
  assert.equal(result.certificate.cancellation_notice_wording, wording);
});

console.log("Stage 4 validation tests complete.");
