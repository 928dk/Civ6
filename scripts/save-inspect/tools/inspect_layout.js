// Inspect the raw map-section layout to find the true tile record stride.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
console.log('mapstart', mapstart, 'tiles', tiles);

// candidate tile records: try to find stride by scanning forward with the
// index.js rule and showing when a preamble repeats
let m = mapstart + 16;
const pre = [];
for (let i = 0; i < 60; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  let bl = 0;
  if (num) bl += 24;
  if (num2 >= 64) bl += 17;
  pre.push(`${i}: off=${m} n2=${num2} n=${num} bl=${bl} head=${bin.slice(m, m + 10).toString('hex')}`);
  m += 55 + bl;
}
console.log(pre.join('\n'));

// Also: hexdump around mapstart
console.log('\n--- mapstart -32 .. +48 ---');
console.log(bin.slice(mapstart - 32, mapstart + 48).toString('hex'));