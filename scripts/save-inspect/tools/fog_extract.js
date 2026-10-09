// Find all observing-section headers (marker 0x11351026) in the bin -> team block layout.
// First team's fog bitmap sits before the FIRST occurrence: [NumTiles][567-byte bitmap].
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const m26 = Buffer.from([0x26, 0x10, 0x35, 0x11]);
const idxs = [];
let i = 0;
while ((i = bin.indexOf(m26, i)) !== -1 && idxs.length < 40) { idxs.push(i); i += 1; }
console.log(`0x11351026 headers (${idxs.length}):`);
idxs.forEach((p, n) => {
  const v05 = bin.readInt32LE(p - 4);
  const v00 = bin.readInt32LE(p + 4);
  const cnt = bin.readInt32LE(p + 8);
  const wid = bin.readInt32LE(p + 12);
  const cnt2 = bin.readInt32LE(p + 16);
  console.log(`  #${n} @0x${p.toString(16)} [05]@-4=${v05} [00]@+4=${v00} cnt=${cnt} wid=${wid} cnt2=${cnt2}`);
});

if (idxs.length) {
  const first = idxs[0];
  // fog bitmap: [NumTiles int32][567 bytes] immediately before [05][11351026]...
  // so bitmap start = first - 4 - 567   (the NumTiles int32 = 4536 at first-4-567-4)
  const start = first - 4 - 567 - 4;
  console.log(`\nfog candidate start 0x${start.toString(16)}: NumTiles=${bin.readInt32LE(start)}`);
  const fog = bin.slice(start + 4, start + 4 + 567);
  // render as bits: tile i visible if bit set. Which bit order? try lsb-first per byte.
  const bits = new Array(4536).fill(0);
  for (let b = 0; b < 567; b++) {
    const byte = fog[b];
    for (let bit = 0; bit < 8; bit++) {
      if (byte & (1 << bit)) bits[b * 8 + bit] = 1;
    }
  }
  const setCount = bits.reduce((a, x) => a + x, 0);
  console.log(`fog non-zero bytes sum: ${[...fog].reduce((a, x) => a + (x ? 1 : 0), 0)}/567, set bits: ${setCount}`);
  console.log('\nfog map (x:set .:clear):');
  for (let y = 0; y < 54; y++) {
    let row = '';
    for (let x = 0; x < 84; x++) row += bits[y * 84 + x] ? '#' : '.';
    console.log(String(y).padStart(2) + ' ' + row);
  }
  // non-zero bytes positions for reference
  const nz = [];
  for (let b = 0; b < 567; b++) if (fog[b]) nz.push(b);
  console.log('nonzero fog bytes:', nz.join(','), '(byte index -> tile ' + nz.map(x => x * 8).join(',') + ')');
}