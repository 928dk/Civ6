// Cross-save diff: same game (AutoSave_0007 = turn 7, HARALD16 = turn 16).
// Terrain/features/rivers are immutable between saves; ownership/units/improvements change.
// For each tile, walk both saves with the model and compare the 55-byte headers.
// Output: per-byte-offset equality rate; per-tile equal-byte count (alignment zones);
// and a list of candidate feature offsets (immutable, values look like small indices).
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);

const saveA = process.argv[2]; // turn 7
const saveB = process.argv[3]; // turn 16
const binA = decompress(fs.readFileSync(saveA));
const binB = decompress(fs.readFileSync(saveB));
const msA = binA.indexOf(searchBuffer);
const msB = binB.indexOf(searchBuffer);
const tiles = binA.readInt32LE(msA + 12);
const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;
console.log(`mapSig A@0x${msA.toString(16)} B@0x${msB.toString(16)} tiles=${tiles} W=${W}`);

// walk both, but DO NOT follow the model blindly: for each tile read num/num2 from EACH save with a
// candidate alignment that allows each save's OWN drift; instead just model-walk both and record.
const mB0 = msB + 16;
let mA = msA + 16, mB = mB0;
const equalByOffset = new Array(55).fill(0);
const totalByOffset = new Array(55).fill(0);
const equalBytesPerTile = [];
const alignedTiles = [];   // tiles where >= 45/55 bytes equal
const mutated = [];        // tiles where many bytes differ (possible unit/improvement change)

for (let i = 0; i < tiles; i++) {
  const hA = binA.slice(mA, mA + 55);
  const hB = binB.slice(mB, mB + 55);
  let eq = 0;
  const diffs = [];
  for (let b = 0; b < 55; b++) {
    totalByOffset[b]++;
    if (hA[b] === hB[b]) { equalByOffset[b]++; eq++; }
    else diffs.push(b);
  }
  equalBytesPerTile.push(eq);
  if (eq >= 45) alignedTiles.push(i);
  else if (eq < 20) mutated.push({ i, eq, diffs: diffs.slice(0, 25).join(',') });

  const n2 = binA.readUInt8(mA + 49);
  const num = binA.readUInt32LE(mA + 51);
  mA += 55 + (num ? 24 : 0) + (n2 >= 64 ? 17 : 0);
  const n2B = binB.readUInt8(mB + 49);
  const numB = binB.readUInt32LE(mB + 51);
  mB += 55 + (numB ? 24 : 0) + (n2B >= 64 ? 17 : 0);
}

console.log('\nper-offset equality rate (offset: eq/total [%]):');
for (let b = 0; b < 55; b++) {
  const pct = Math.round(100 * equalByOffset[b] / totalByOffset[b]);
  if (pct > 0) console.log(`  +${String(b).padStart(2)}: ${String(equalByOffset[b]).padStart(4)}/${totalByOffset[b]} (${pct}%)` + (pct <= 25 ? '  <-- CHANGED' : ''));
}
console.log(`\naligned tiles (>=45/55 equal): ${alignedTiles.length}/${tiles}`);
console.log(`mutated tiles (<20/55 equal): ${mutated.length}`);
console.log('first 10 aligned:', alignedTiles.slice(0, 10).map(i => `(${i % W},${Math.floor(i / W)})`).join(' '));
console.log('last 10 aligned:', alignedTiles.slice(-10).map(i => `(${i % W},${Math.floor(i / W)})`).join(' '));
console.log('\nfirst 20 mutated:', mutated.slice(0, 20).map(m => `(${m.i % W},${Math.floor(m.i / W)}) eq=${m.eq} d=${m.diffs}`).join('\n  '));