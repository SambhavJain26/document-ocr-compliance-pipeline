export function parseISODate(value){if(!/^\d{4}-\d{2}-\d{2}$/.test(value||''))return null;const d=new Date(value+'T00:00:00Z');return Number.isNaN(+d)||d.toISOString().slice(0,10)!==value?null:d;}
