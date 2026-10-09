// Histogram of num (u32 at +51), num2 (u8 at +49) and river (+45) across the
// walked records of AutoSave_0007, first N tiles (assumed aligned early).
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;

// walk first N
const N = 400;
let m = mapstart + 16;
const numHist = {};
const num2Hist = {};
const riverHist = {};
const lenHist = {};
let driftFail = 0;
for (let i = 0; i < N; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  const r = bin.readUInt8(m + 45);
  numHist[num] = (numHist[num] || 0) + 1;
  num2Hist[num2] = (num2Hist[num2] || 0) + 1;
  riverHist[r] = (riverHist[r] || 0) + 1;
  const L = 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
  lenHist[L] = (lenHist[L] || 0) + 1;
  // sanity: header fields of next record should be inside bin
  if (m + L + 55 > bin.length) driftFail++;
  m += L;
}
console.log('num (u32@+51) hist:', JSON.stringify(numHist));
console.log('num2 (u8@+49) hist:', JSON.stringify(num2Hist));
console.log('river (u8@+45) hist:', JSON.stringify(riverHist));
console.log('record len hist:', JSON.stringify(lenHist));
console.log('walk end offset 0x' + m.toString(16));

// first 20 records hex-dumped for eyeballing
m = mapstart + 16;
console.log('\nfirst 20 records:');
for (let i = 0; i < 20; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  const L = 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
  console.log(`t${i} n2=${num2} num=${num} L=${L} hex=${bin.slice(m, m + 55).toString('hex')}`);
  m += L;
}