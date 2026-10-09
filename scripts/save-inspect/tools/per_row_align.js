// Per-row alignment analysis under bool & count(4+20n) models.
// For rows that are aligned, print +37 (feature), +12,+16 for the cape/Islandia regions.
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
const W = 84, H = tiles / W;

function walk(model) {
  let mA = msA + 16, mB = msB + 16;
  const rowAligned = new Array(H).fill(0);
  const rowTotal = new Array(H).fill(0);
  const f37 = []; // per-tile feature byte (only where aligned)
  const alignedFlags = new Array(tiles).fill(false);
  for (let i = 0; i < tiles; i++) {
    let numA, n2A, numB, n2B;
    if (mA + 55 <= binA.length) { n2A = binA.readUInt8(mA + 49); numA = binA.readUInt32LE(mA + 51); } else { numA = 0; n2A = 0; }
    if (mB + 55 <= binB.length) { n2B = binB.readUInt8(mB + 49); numB = binB.readUInt32LE(mB + 51); } else { numB = 0; n2B = 0; }
    let L_A, L_B;
    if (model === 'bool') {
      L_A = 55 + (numA ? 24 : 0) + (n2A >= 64 ? 17 : 0);
      L_B = 55 + (numB ? 24 : 0) + (n2B >= 64 ? 17 : 0);
    } else { // count 4+20n
      L_A = 55 + 4 + 20 * (numA > 16 ? 0 : numA) + (n2A >= 64 ? 17 : 0);
      L_B = 55 + 4 + 20 * (numB > 16 ? 0 : numB) + (n2B >= 64 ? 17 : 0);
    }
    let eq = 0;
    if (mA + 55 <= binA.length && mB + 55 <= binB.length) {
      for (let b = 0; b < 55; b++) if (binA[mA + b] === binB[mB + b]) eq++;
      const y = Math.floor(i / W);
      rowTotal[y]++;
      if (eq >= 45) { rowAligned[y]++; alignedFlags[i] = true; f37[i] = binA.readUInt8(mA + 37); }
    }
    mA += L_A; mB += L_B;
  }
  return { rowAligned, rowTotal, f37, alignedFlags };
}

for (const model of ['bool', 'count']) {
  const r = walk(model);
  console.log(`\n=== ${model}-model per-row alignment ===`);
  const rows = [];
  for (let y = 0; y < H; y++) rows.push(`y${y}:${r.rowAligned[y]}/${r.rowTotal[y]}`);
  console.log(rows.join(' '));
  // print feature byte grid for rows 34-46 (cape region) where aligned
  console.log(`\n${model}: +37 feature bytes, rows 34-46 (x51-71) — aligned only ('.' unaligned):`);
  for (let y = 34; y <= 46; y++) {
    let line = '';
    for (let x = 51; x <= 71; x++) {
      const i = y * W + x;
      if (r.alignedFlags[i]) {
        const v = r.f37[i];
        line += v === 255 ? '.' : (v === 0 ? '_' : v.toString(16));
      } else line += '?';
    }
    console.log(`y${String(y).padStart(2)} ${line}`);
  }
  // store for possible further use
  global.__r = r;
}

// Also: how many tiles have feature != 255/0 anywhere (under bool), where aligned?
const r = walk('bool');
const featTiles = [];
for (let i = 0; i < tiles; i++) {
  if (r.alignedFlags[i] && r.f37[i] !== 255 && r.f37[i] !== 0) {
    featTiles.push({ x: i % W, y: Math.floor(i / W), f: r.f37[i] });
  }
}
console.log('\nbool-model aligned tiles with feature != 0/255:', featTiles.length);
console.log(featTiles.map(t => `(${t.x},${t.y})f=${t.f}`).join(' '));
// distinct feature values distribution
const dist = {};
for (const t of featTiles) dist[t.f] = (dist[t.f] || 0) + 1;
console.log('distribution:', JSON.stringify(dist));