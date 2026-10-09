// Histogram num (u32@+51) and num2 (u8@+49) on our Aspyr saves + dump a num=2 record hex.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);

for (const savePath of process.argv.slice(2)) {
  const bin = decompress(fs.readFileSync(savePath));
  const mapstart = bin.indexOf(searchBuffer);
  const tiles = bin.readInt32LE(mapstart + 12);
  const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;
  const numHist = {}, num2Hist = {};
  let m = mapstart + 16;
  let maxNum = 0, num2max = 0;
  for (let i = 0; i < tiles; i++) {
    const num2 = bin.readUInt8(m + 49);
    const num = bin.readUInt32LE(m + 51);
    numHist[num] = (numHist[num] || 0) + 1;
    num2Hist[num2] = (num2Hist[num2] || 0) + 1;
    if (num > maxNum) maxNum = num;
    if (num2 > num2max) num2max = num2;
    m += 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
  }
  console.log(`\n=== ${savePath.split('/').pop()} ===`);
  console.log('num hist:', JSON.stringify(numHist));
  console.log('num2 hist (value:count):', Object.entries(num2Hist).sort((a, b) => a[0] - b[0]).map(([k, v]) => `${k}:${v}`).join(' '));
  console.log('maxNum', maxNum, 'num2max', num2max);
}

// Dump the 5th tile record from AutoSave_0007 half-aligned? -- instead dump first 5 records raw (aligned region)
console.log('\n=== first 6 records of AutoSave_0007 (raw bytes, model walk) ===');
{
  const savePath = process.argv[2];
  const bin = decompress(fs.readFileSync(savePath));
  const mapstart = bin.indexOf(searchBuffer);
  let m = mapstart + 16;
  for (let i = 0; i < 6; i++) {
    const num2 = bin.readUInt8(m + 49);
    const num = bin.readUInt32LE(m + 51);
    const L = 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
    console.log(`t${i} n2=${num2} num=${num} L=${L}`);
    console.log(`  hdr: ${bin.slice(m, m + 55).toString('hex')}`);
    if (num) console.log(`  ovr: ${bin.slice(m + 55, m + 55 + 24).toString('hex')}`);
    if (num2 >= 64) console.log(`  own: ${bin.slice(m + 55 + (num ? 24 : 0), m + L).toString('hex')}`);
    m += L;
  }
}