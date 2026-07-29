export function normaliseName(raw = '') {
  return raw
    .toLowerCase()
    .replace(
      /(^|[^a-z0-9])(l\.l\.c\.?|llc|incorporated|inc\.?|corporation|corp\.?|company|co\.?|limited|ltd\.?|pllc|llp|lp|pc|dba)(?=$|[^a-z0-9])/g,
      '$1',
    )
    .replace(/[^a-z0-9 ]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}
