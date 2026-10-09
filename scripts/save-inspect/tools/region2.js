// Region dump with decoded fields for a specific save + rect.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath, rect] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;

const meta = [];
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
console.log(`save=${savePath.split('/').pop()} tiles=${tiles} W=${W} lastOff=0x${m.toString(16)}`);

const [x0, y0, x1, y1] = rect.split(',').map(Number);
for (let y = y0; y <= y1; y++) {
  const cells = [];
  for (let x = x0; x <= x1; x++) {
    const t = meta[y * W + x];
    if (!t) { cells.push(`${x},${y}:OOB`); continue; }
    const b = bin;
    const i32_12 = b.readInt32LE(t.off + 12);
    const i32_16 = b.readInt32LE(t.off + 16);
    const featureByte = b.readUInt8(t.off + 16);   // low byte of +16
    const b12 = b.readUInt8(t.off + 12);           // low byte of +12 (terrain?)
    const b13 = b.readUInt8(t.off + 13);
    const b14 = b.readUInt8(t.off + 14);
    const b15 = b.readUInt8(t.off + 15);
    cells.push(`${x},${y}:t${b12}/${b13} f${featureByte} i16=${i32_16.toString(16)}`);
  }
  console.log(cells.join('  '));
}