// Render candidate byte offsets as ASCII maps to find terrain/feature bytes.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;
const H = tiles / W;

const offs = [];
let m = mapstart + 16;
for (let i = 0; i < tiles; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  offs.push(m);
  m += 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
}

const interesting = [8,9,10,11,12,13,14,15,16,17,18,19,20,21,26,37,38,39,40,41,42,43,44,45,46,47];
// plus u16s at 0,2,4,6,8,10,20,31,40
const u16s = [0,2,4,6,8,10,20,31,40];

function render(off, mode, label) {
  const chars = [];
  for (let y = 0; y < H; y++) {
    let row = '';
    for (let x = 0; x < W; x++) {
      const o = offs[y * W + x];
      let v;
      if (mode === 'u8') v = bin.readUInt8(o + off);
      else v = bin.readUInt16LE(o + off);
      // bucket to a char
      let c;
      if (v >= 250) c = '#';       // high/ff
      else if (v >= 100) c = 'O';  // mid-high
      else if (v >= 40) c = '+';   // mid
      else if (v >= 10) c = '.';   // low-mid
      else if (v >= 1) c = ':';    // low
      else c = ' ';                // zero
      row += c;
    }
    chars.push(row);
  }
  console.log(`\n=== ${label} (${mode} @+${off}) ===`);
  console.log(chars.join('\n'));
}

for (const off of interesting) render(off, 'u8', `u8+${off}`);
//for (const off of u16s) render(off, 'u16', `u16+${off}`);