// Test count-model (55 + 24*num + 17*owns) vs bool-model on the SAME-game save pair.
// Metric: fraction of tiles where the 55-byte headers match (>=45/55 equal) = alignment.
// Also dump the first num=2 record in the aligned prefix for eyeballing.
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

function walkWith(model, B, ms) {
  let m = ms + 16;
  let aligned = 0, oob = 0, clamped = 0;
  const alignedTiles = [];
  // cross-save compare needs both bins; do it in main loop instead
  return { m };
}

// main loop with model param: model 'bool' | 'count'
function run(model) {
  let mA = msA + 16, mB = msB + 16;
  let aligned = 0, oob = 0, clamped = 0;
  const firstNum2 = []; // positions of num>=2 in aligned prefix
  const perTile = [];
  for (let i = 0; i < tiles; i++) {
    let numA, numB, n2A, n2B;
    if (mA + 55 <= binA.length) { n2A = binA.readUInt8(mA + 49); numA = binA.readUInt32LE(mA + 51); } else { numA = 0; n2A = 0; oob++; }
    if (mB + 55 <= binB.length) { n2B = binB.readUInt8(mB + 49); numB = binB.readUInt32LE(mB + 51); } else { numB = 0; n2B = 0; oob++; }
    let L_A, L_B;
    if (model === 'count') {
      if (numA > 8) { numA = 0; clamped++; }
      if (numB > 8) { numB = 0; clamped++; }
      L_A = 55 + 24 * numA + (n2A >= 64 ? 17 : 0);
      L_B = 55 + 24 * numB + (n2B >= 64 ? 17 : 0);
    } else {
      L_A = 55 + (numA ? 24 : 0) + (n2A >= 64 ? 17 : 0);
      L_B = 55 + (numB ? 24 : 0) + (n2B >= 64 ? 17 : 0);
    }
    // compare headers where both in-bounds
    let eq = 0;
    if (mA + 55 <= binA.length && mB + 55 <= binB.length) {
      for (let b = 0; b < 55; b++) if (binA[mA + b] === binB[mB + b]) eq++;
      if (eq >= 45) aligned++;
      if (model === 'count' && numA > 1 && firstNum2.length < 5 && i < 400) firstNum2.push({ i, x: i % W, y: Math.floor(i / W), num: numA, n2: n2A });
    }
    perTile.push(eq);
    mA += L_A; mB += L_B;
  }
  // after bytes
  const afterA = binA.slice(mA, mA + 16).toString('hex');
  const afterB = binB.slice(mB, mB + 16).toString('hex');
  console.log(`${model}-model: aligned=${aligned}/${tiles} (${Math.round(100 * aligned / tiles)}%) oob=${oob} clamped=${clamped}`);
  console.log(`  end A=0x${mA.toString(16)} after=${afterA}`);
  console.log(`  end B=0x${mB.toString(16)} after=${afterB}`);
  if (firstNum2.length) console.log('  num>=2 in prefix 400:', firstNum2.map(f => `(${f.x},${f.y})num=${f.num}n2=${f.n2}@idx${f.i}`).join(' '));
  return perTile;
}

console.log(`tiles=${tiles} W=${W}`);
const boolP = run('bool');
console.log('');
const countP = run('count');
console.log('');

// Where do they differ per tile? Show transition tiles for count model:
// find tiles where count-alignment is new (aligned in count but <45 eq in bool)
let gains = 0, losses = 0;
for (let i = 0; i < tiles; i++) {
  if (boolP[i] < 45 && countP[i] >= 45) { gains++; if (gains <= 8) console.log(`gain @(${i % W},${Math.floor(i / W)}) idx${i} bool_${boolP[i]} count_${countP[i]}`); }
  if (boolP[i] >= 45 && countP[i] < 45) losses++;
}
console.log(`\ngains (new aligned tiles): ${gains}, losses: ${losses}`);

// ---- dump the first num=2 record from count-walk in save A ----
console.log('\n=== first num=2 record dump (save A, count-model walk) ===');
{
  let m = msA + 16;
  for (let i = 0; i < tiles && m + 55 <= binA.length; i++) {
    const n2 = binA.readUInt8(m + 49);
    const num = binA.readUInt32LE(m + 51);
    if (i < 400 && num === 2) {
      console.log(`idx ${i} (${i % W},${Math.floor(i / W)}) n2=${n2}`);
      console.log(`  hdr(55): ${binA.slice(m, m + 55).toString('hex')}`);
      console.log(`  ov1(24): ${binA.slice(m + 55, m + 79).toString('hex')}`);
      console.log(`  ov2(24): ${binA.slice(m + 79, m + 103).toString('hex')}`);
      break;
    }
    const L = 55 + 24 * (num > 8 ? 0 : num) + (n2 >= 64 ? 17 : 0);
    m += L;
  }
}