// Show context around the LYSEFJORDEN / EYJAFJALLA strings in a decompressed save.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const save = process.argv[2];
const bin = decompress(fs.readFileSync(save));
console.log('save:', save.split('/').pop(), 'size:', bin.length);
for (const needle of ['LYSEFJORDEN', 'EYJAFJALLA', 'CRATER_LAKE']) {
  const hits = [];
  let idx = 0;
  while ((idx = bin.indexOf(Buffer.from(needle), idx)) !== -1) { hits.push(idx); idx++; }
  console.log(`\n${needle}: ${hits.length} hits`);
  for (const h of hits.slice(0, 4)) {
    const ctx = bin.slice(Math.max(0, h - 160), h + 260).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
    console.log(`  @0x${h.toString(16)}: ...${ctx}...`);
  }
}