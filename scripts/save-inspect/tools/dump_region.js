// Print raw tile header bytes for selected regions, for calibration.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath, ...rects] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;

const meta = [];   // per-tile: offset
let m = mapstart + 16;
for (let i = 0; i < tiles; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  let bl = 0;
  if (num) bl += 24;
  if (num2 >= 64) bl += 17;
  meta.push({ off: m, len: 55 + bl, num2, num });
  m += 55 + bl;
}

function dumpRegion(x0, y0, x1, y1, label) {
  console.log(`\n=== ${label} (x${x0}..${x1}, y${y0}..${y1}) ===`);
  for (let y = y0; y <= y1; y++) {
    const line = [];
    for (let x = x0; x <= x1; x++) {
      const t = meta[y * W + x];
      const b = bin;
      const h = b.slice(t.off, t.off + 55).toString('hex');
      line.push(`${x},${y}:${h}`);
    }
    console.log(line.join('  '));
  }
}

// parse rects like "50,34-66,45"
for (const rect of rects) {
  const [a, b] = rect.split('-');
  const [x0, y0] = a.split(',').map(Number);
  const [x1, y1] = b.split(',').map(Number);
  dumpRegion(x0, y0, x1, y1, rect);
}