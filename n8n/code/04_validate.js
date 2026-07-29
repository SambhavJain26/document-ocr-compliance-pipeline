import { normaliseName } from './lib/normalise.js';
import { daysBetween, parseISODate, todayInZone } from './lib/dates.js';
import { tokenSetRatio } from './lib/fuzzy.js';

/**
 * Deterministically applies the Stage 4 validation contract.
 *
 * The n8n Code node pastes the three lib files immediately above this module's
 * body. This importable source is intentionally the canonical, testable copy;
 * no workflow is allowed to reimplement its rules.
 */
export function validate(extraction, config = {}, context = {}) {
  const ex = extraction || {};
  const cfg = {
    holder_match_threshold: 0.80,
    vendor_match_exact: 0.95,
    vendor_match_review: 0.80,
    min_each_occurrence: 1_000_000,
    min_general_aggregate: 2_000_000,
    timezone: 'UTC',
    ...config,
  };
  const ctx = {
    holder_entities: context.holder_entities || context.holders || [],
    vendor_candidates: context.vendor_candidates || context.vendors || [],
    vendor: context.vendor || null,
    existing_certificate: context.existing_certificate || null,
    trade_requirement: context.trade_requirement || null,
  };
  const flags = [];
  const add = (code, severity, detail = null, extra = {}) => {
    if (!flags.some((flag) => flag.code === code && flag.coverage_type === extra.coverage_type)) {
      flags.push({ code, severity, detail, ...extra });
    }
  };

  if (ex.is_certificate_of_insurance === false) {
    return {
      outcome: 'REJECT',
      status: 'REJECTED',
      reason_code: 'NOT_A_COI',
      reason_detail: ex.confidence_reason || 'Document is not a certificate of insurance.',
      flags: [{ code: 'NOT_A_COI', severity: 'hard', detail: null }],
      vendor_id: null,
      vendor_action: 'NONE',
    };
  }

  if (ex.extraction_confidence === 'LOW') add('LOW_CONFIDENCE', 'hard', ex.confidence_reason);

  const coverage = Array.isArray(ex.coverages) ? ex.coverages : [];
  const certDate = parseISODate(ex.certificate_date);
  const today = todayInZone(cfg.timezone);
  const anchor = certDate || parseISODate(today);
  if (ex.certificate_date && !certDate) {
    add('DATE_UNPARSEABLE', 'hard', 'certificate date: "' + ex.certificate_date + '"');
  }

  let earliestExpiration = null;
  for (const cov of coverage) {
    const effective = parseISODate(cov.effective_date);
    const expiration = parseISODate(cov.expiration_date);

    if (effective && expiration && expiration <= effective) {
      add(
        'DATE_INVERTED',
        'hard',
        cov.type + ': expires ' + cov.expiration_date + ', effective ' + cov.effective_date,
        { coverage_type: cov.type },
      );
    }
    for (const [label, raw, date] of [
      ['effective', cov.effective_date, effective],
      ['expiration', cov.expiration_date, expiration],
    ]) {
      if (raw && !date) {
        add('DATE_UNPARSEABLE', 'hard', cov.type + ' ' + label + ': "' + raw + '"', { coverage_type: cov.type });
      } else if (date && anchor) {
        const delta = daysBetween(anchor, date);
        if (delta < -730 || delta > 1095) {
          add(
            'DATE_IMPLAUSIBLE',
            'hard',
            cov.type + ' ' + label + ' ' + raw + ' is ' + delta + ' days from certificate date',
            { coverage_type: cov.type },
          );
        }
      }
    }
    if (expiration && (!earliestExpiration || expiration < earliestExpiration)) earliestExpiration = expiration;
  }

  const gl = coverage.find((cov) => cov.type === 'GENERAL_LIABILITY');
  if (!gl) add('NO_GL_LINE', 'soft', 'No Commercial General Liability line on this certificate');

  const requirement = ctx.trade_requirement || {};
  const minimumEach = Number(requirement.min_each_occurrence ?? cfg.min_each_occurrence);
  const minimumAggregate = Number(requirement.min_general_aggregate ?? cfg.min_general_aggregate);
  if (gl) {
    if (gl.each_occurrence != null && minimumEach && Number(gl.each_occurrence) < minimumEach) {
      add('LIMIT_BELOW_MINIMUM', 'soft', 'GL each occurrence is below the required minimum');
    }
    if (gl.general_aggregate != null && minimumAggregate && Number(gl.general_aggregate) < minimumAggregate) {
      add('AGGREGATE_BELOW_MINIMUM', 'soft', 'GL aggregate is below the required minimum');
    }
  }

  const wcRequired = requirement.wc_required !== false && !ctx.vendor?.wc_exempt;
  if (wcRequired && !coverage.some((cov) => cov.type === 'WORKERS_COMP')) {
    add('NO_WC_LINE', 'soft', 'No workers compensation line and vendor is not marked WC-exempt');
  }

  const holder = normaliseName(ex.certificate_holder);
  let bestHolder = { score: 0, entity: null };
  for (const entity of ctx.holder_entities) {
    const candidate = normaliseName(entity.normalised || entity.legal_name);
    const score = tokenSetRatio(holder, candidate);
    if (score > bestHolder.score) bestHolder = { score, entity: entity.legal_name };
  }
  const holderMatch = ctx.holder_entities.length === 0 || bestHolder.score >= Number(cfg.holder_match_threshold);
  if (!holderMatch) {
    add(
      'HOLDER_MISMATCH',
      'soft',
      'Certificate names "' + (ex.certificate_holder || '(blank)') + '"; closest accepted entity "' +
        (bestHolder.entity || 'none') + '" at ' + bestHolder.score.toFixed(2),
    );
  }

  const vendorName = normaliseName(ex.vendor_legal_name);
  let bestVendor = { score: 0, vendor: null };
  for (const vendor of ctx.vendor_candidates) {
    const score = tokenSetRatio(vendorName, normaliseName(vendor.normalised_name || vendor.legal_name));
    if (score > bestVendor.score) bestVendor = { score, vendor };
  }

  let vendorId = null;
  let vendorAction = 'CREATE';
  if (bestVendor.vendor && bestVendor.score >= Number(cfg.vendor_match_exact)) {
    vendorId = bestVendor.vendor.id;
    vendorAction = 'MATCH';
  } else if (bestVendor.vendor && bestVendor.score >= Number(cfg.vendor_match_review)) {
    vendorAction = 'REVIEW';
    add(
      'POSSIBLE_DUPLICATE_VENDOR',
      'hard',
      '"' + ex.vendor_legal_name + '" resembles "' + bestVendor.vendor.legal_name + '". Human review required.',
      { candidate_vendor_id: bestVendor.vendor.id },
    );
  }

  let coverageGapDays = null;
  const existing = ctx.existing_certificate;
  if (vendorAction === 'MATCH' && existing) {
    const oldCertificateDate = parseISODate(existing.certificate_date);
    if (certDate && oldCertificateDate && certDate < oldCertificateDate) {
      add('OLDER_THAN_ON_FILE', 'hard', 'Certificate is older than the certificate already on file');
    } else {
      const oldExpiration = parseISODate(existing.earliest_expiration);
      const newEffective = coverage
        .map((cov) => parseISODate(cov.effective_date))
        .filter(Boolean)
        .sort((a, b) => a - b)[0];
      if (oldExpiration && newEffective && newEffective > oldExpiration) {
        coverageGapDays = daysBetween(oldExpiration, newEffective);
        add(
          'COVERAGE_GAP',
          'soft',
          coverageGapDays + '-day gap between prior expiration and replacement effective date',
          { gap_days: coverageGapDays },
        );
      }
    }
  }

  const hasHard = flags.some((flag) => flag.severity === 'hard');
  return {
    outcome: 'STORE',
    status: hasHard ? 'NEEDS_REVIEW' : 'ON_FILE',
    flags,
    vendor_id: vendorId,
    vendor_action: vendorAction,
    vendor_match_score: bestVendor.score,
    holder_match: holderMatch,
    holder_matched_entity: holderMatch ? bestHolder.entity : null,
    coverage_gap_days: coverageGapDays,
    earliest_expiration: earliestExpiration ? earliestExpiration.toISOString().slice(0, 10) : null,
    supersede_certificate_id: vendorAction === 'MATCH' && existing && !hasHard ? existing.id : null,
    today,
  };
}
