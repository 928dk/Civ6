// Extract the Features table region from a save's serialized DB dump and inspect.
// Sequence: find all feature name strings, group them, dump the region around the features table.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const save = process.argv[2];
const bin = decompress(fs.readFileSync(save));
console.log('save:', save.split('/').pop(), 'size:', bin.length);

// find "Features" table marker: look for the string "Features" followed by table columns
const markers = [];
let idx = 0;
while ((idx = bin.indexOf(Buffer.from('Features'), idx)) !== -1) { markers.push(idx); idx++; }
console.log(`'Features' markers: ${markers.length}`);
for (const m of markers.slice(0, 30)) {
  const ctx = bin.slice(m, m + 200).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
  console.log(`  @0x${m.toString(16)}: ${ctx.slice(0, 120)}`);
}

// Find all vanilla feature names and where they appear — if Lysefjorden is in the same table region as Crater Lake, it's serialized.
const feats = ['FEATURE_FLOODPLAINS','FEATURE_ICE','FEATURE_JUNGLE','FEATURE_FOREST','FEATURE_OASIS','FEATURE_MARSH',
  'FEATURE_BARRIER_REEF','FEATURE_CLIFFS_DOVER','FEATURE_CRATER_LAKE','FEATURE_DEAD_SEA','FEATURE_EVEREST',
  'FEATURE_GALAPAGOS','FEATURE_KILIMANJARO','FEATURE_PANTANAL','FEATURE_PIOPIOTAHI','FEATURE_TORRES_DEL_PAINE',
  'FEATURE_TSINGY','FEATURE_YOSEMITE','FEATURE_LYSEFJORDEN','FEATURE_EYJAFJALLAJOKULL','FEATURE_GIANTS_CAUSEWAY'];
const hits = {};
for (const f of feats) {
  const pos = [];
  let i = 0;
  while ((i = bin.indexOf(Buffer.from(f), i)) !== -1) { pos.push(i); i++; }
  hits[f] = pos;
  console.log(`${f}: ${pos.length} hits ${pos.slice(0, 4).map(p => '0x' + p.toString(16)).join(' ')}`);
}
// table region: FEATURE_FLOODPLAINS first hit
if (hits['FEATURE_FLOODPLAINS'].length) {
  const a = hits['FEATURE_FLOODPLAINS'][0];
  console.log('\n--- region around Features table start ---');
  console.log(bin.slice(a - 400, a + 1200).toString('latin1').replace(/[^\x20-\x7e]/g, '.'));
}