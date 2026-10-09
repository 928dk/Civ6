// Find all occurrences of 4536 (tile count) int32 LE and inspect context.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const needles = [4536, 84, 54, 106, 66, 6996];
for (const n of needles) {
  const b = Buffer.alloc(4); b.writeInt32LE(n);
  const idxs = [];
  let i = 0;
  while ((i = bin.indexOf(b, i)) !== -1 && idxs.length < 25) { idxs.push(i); i += 4; }
  if (idxs.length) console.log(`${n}: ${idxs.map(i => '0x' + i.toString(16)).join(', ')}`);
}
console.log('\ncontext of 4536 occurrences:');
let i = 0;
const b = Buffer.alloc(4); b.writeInt32LE(4536);
let count = 0;
while ((i = bin.indexOf(b, i)) !== -1 && count < 12) {
  const asc = bin.slice(Math.max(0, i - 32), i + 32).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
  console.log(`0x${i.toString(16)}: ${bin.slice(Math.max(0, i - 24), i + 24).toString('hex')}  asc:${asc}`);
  i += 4; count++;
}