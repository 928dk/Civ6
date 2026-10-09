// Refined: restrict comparisons to tiles where BOTH walks are aligned (>=45/55 header bytes equal).
// Then histogram values at candidate offsets (+12..+19, +22..+31, +37..+47).
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);

const saveA = process.argv[2];
const saveB = process.argv[3];
const binA = decompress(fs.readFileSync(saveA));
const binB = decompress(fs.readFileSync(saveB));
const msA = binA.indexOf(searchBuffer);
const msB = binB.indexOf(searchBuffer);
const tiles = binA.readInt32LE(msA + 12);
const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;

let mA = msA + 16, mB = msB + 16;
let aligned = 0;
const eqByOff = new Array(55).fill(0);
const histByOff = {};   // offset -> valueHist (only aligned tiles, from save A)
const mutated = [];
for (let i = 0; i < tiles; i++) {
  const hA = binA.slice(mA, mA + 55);
  const hB = binB.slice(mB, mB + 55);
  let eq = 0;
  const diffs = [];
  for (let b = 0; b < 55; b++) {
    if (hA[b] === hB[b]) eq++;
    else diffs.push(b);
  }
  if (eq >= 45) {
    aligned++;
    for (let b = 0; b < 55; b++) {
      if (hA[b] === hB[b]) eqByOff[b]++;
      const v = hA[b];
      (histByOff[b] || (histByOff[b] = {}))[v] = (histByOff[b][v] || 0) + 1;
    }
  } else {
    mutated.push({ i, eq, x: i % W, y: Math.floor(i / W), d: diffs.slice(0, 20).join(',') });
  }

  const n2A = binA.readUInt8(mA + 49);
  const numA = binA.readUInt32LE(mA + 51);
  mA += 55 + (numA ? 24 : 0) + (n2A >= 64 ? 17 : 0);
  const n2B = binB.readUInt8(mB + 49);
  const numB = binB.readUInt32LE(mB + 51);
  mB += 55 + (numB ? 24 : 0) + (n2B >= 64 ? 17 : 0);
}

console.log(`aligned tiles: ${aligned}/${tiles}`);
console.log('\nper-offset equality (aligned only):');
for (let b = 0; b < 55; b++) {
  const pct = Math.round(100 * eqByOff[b] / aligned);
  console.log(`  +${String(b).padStart(2)}: ${pct}%` + (pct <= 60 ? '  <-- changes between turns' : ''));
}

console.log('\nvalue histograms (aligned only, save A) for offsets with >=90% equality:');
const interesting = [];
for (let b = 0; b < 55; b++) {
  if (eqByOff[b] / aligned >= 0.9) {
    const h = histByOff[b];
    const entries = Object.entries(h).sort((a, b) => b[1] - a[1]).slice(0, 12);
    console.log(`  +${String(b).padStart(2)} (${Math.round(100 * eqByOff[b] / aligned)}%): ` + entries.map(([k, c]) => `0x${(+k).toString(16)}=${c}`).join(' '));
    interesting.push(b);
  }
}
console.log('\ninteresting offsets:', interesting.join(','));

// For the aligned tiles, dump coordinates of tiles where ANY of these offsets has a "feature-ish" value
// (small 1..31) at offsets +22..+30 (the doc's terrain/resource zone)... instead, dump raw +22..+30 for
// a sample of aligned tiles to eyeball.
console.log('\nsample aligned tile fields (first 25):');
let mA2 = msA + 16, mB2 = msB + 16;
let count = 0;
for (let i = 0; i < tiles && count < 25; i++) {
  const hA = binA.slice(mA2, mA2 + 55);
  const hB = binB.slice(mB2, mB2 + 55);
  let eq = 0;
  for (let b = 0; b < 55; b++) if (hA[b] === hB[b]) eq++;
  if (eq >= 45) {
    const x = i % W, y = Math.floor(i / W);
    const f12 = hA.slice(12, 16).toString('hex');
    const f16 = hA.slice(16, 20).toString('hex');
    const f22 = hA.slice(22, 26).toString('hex');
    const f27 = hA.slice(27, 31).toString('hex');
    const f31 = hA.readUInt16LE(31);
    const f33 = hA.slice(33, 37).toString('hex');
    const f37 = hA[37], f45 = hA[45], f46 = hA[46], f47 = hA[47];
    console.log(`(${String(x).padStart(2)},${String(y).padStart(2)}) +12=${f12} +16=${f16} +22=${f22} +27=${f27} +31=${f31} +33=${f33} +37=${f37} +45=${f45} +46=${f46.toString(2).padStart(8,'0')} +47=${f47.toString(2).padStart(8,'0')}`);
    count++;
  }
  const n2A = binA.readUInt8(mA2 + 49);
  const numA = binA.readUInt32LE(mA2 + 51);
  mA2 += 55 + (numA ? 24 : 0) + (n2A >= 64 ? 17 : 0);
  const n2B = binB.readUInt8(mB2 + 49);
  const numB = binB.readUInt32LE(mB2 + 51);
  mB2 += 55 + (numB ? 24 : 0) + (n2B >= 64 ? 17 : 0);
}

// mutated tile geography: clusters?
console.log('\nmutated tile rows (y: count):');
const rowCnt = {};
for (const m of mutated) rowCnt[m.y] = (rowCnt[m.y] || 0) + 1;
console.log(Object.entries(rowCnt).sort((a, b) => a[0] - b[0]).map(([y, c]) => `y${y}=${c}`).join(' '));