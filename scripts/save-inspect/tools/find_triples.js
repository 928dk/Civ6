// Find count/width/count triples (4536, 84, 4536) and other distinctive structures in the bin.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
console.log('bin size', bin.length);

const TILES = 4536, W = 84;

// triple: 11 B8 00 00 | 54 00 00 00 | 11 B8 00 00
const triple = Buffer.from([0x11, 0xb8, 0x00, 0x00, 0x54, 0x00, 0x00, 0x00, 0x11, 0xb8, 0x00, 0x00]);
const idxs = [];
let i = 0;
while ((i = bin.indexOf(triple, i)) !== -1 && idxs.length < 40) { idxs.push(i); i += 1; }
console.log(`count/width/count triples (${idxs.length}):`, idxs.map(i => '0x' + i.toString(16)).join(', '));

for (const t of idxs) {
  const ctx = bin.slice(t - 8, t + 24).toString('hex');
  console.log(`0x${t.toString(16)} ctx: ...${ctx}...`);
}
console.log('\n--- first triple context (48 before, 64 after) ---');
if (idxs.length) {
  const t = idxs[0];
  console.log(bin.slice(t - 48, t + 64).toString('hex'));
}