/**
 * Sørensen-Dice token score. It gives "Mercer Plumbing" versus
 * "Mercer Plumbing Heating" 0.80, the near-match review threshold.
 */
export function tokenSetRatio(left = '', right = '') {
  const a = new Set(left.split(' ').filter(Boolean));
  const b = new Set(right.split(' ').filter(Boolean));
  if (!a.size || !b.size) return 0;
  const shared = [...a].filter((token) => b.has(token)).length;
  return (2 * shared) / (a.size + b.size);
}
