// Scan all tiles for river (u8+45) and river-orientation bitmap (u8+46),
// plus dump +37..+39 and +16 fields for the cape vicinity.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;
const H = tiles / W;

const meta = [];
let m = mapstart + 16;
for (let i = 0; i < tiles; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  meta.push(m);
  m += 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
}

// 1. river census
const riv = [];
for (let i = 0; i < tiles; i++) {
  const o = meta[i];
  const r = bin.readUInt8(o + 45);
  if (r) riv.push({ i, x: i % W, y: Math.floor(i / W), r, ori: bin.readUInt8(o + 46) });
}
console.log(`river tiles: ${riv.length}`);
console.log(riv.map(t => `(${t.x},${t.y}) sides=${t.r} ori=${t.ori.toString(16)}`).join(' '));

// 2. cape vicinity grid: show u8+45, +46, +16 low byte, +12 bytes
const x0 = 48, y0 = 33, x1 = 66, y1 = 44;
console.log(`\ncape grid legend: R=river else .  (u8+45)`);
for (let y = y0; y <= y1; y++) {
  let row = '';
  for (let x = x0; x <= x1; x++) {
    const o = meta[y * W + x];
    const r = bin.readUInt8(o + 45);
    row += r ? 'R' : '.';
  }
  console.log(`${String(y).padStart(2)} ${row}`);
}

// 3. full-map grid for u8+16 (low byte of the "ice+forest/feature" field)
const counts = {};
const feat16 = [];
for (let i = 0; i < tiles; i++) {
  const v = bin.readUInt8(meta[i] + 16);
  counts[v] = (counts[v] || 0) + 1;
  if (v !== 255) feat16.push({ x: i % W, y: Math.floor(i / W), v });
}
console.log(`\nu8+16 value census (excluding 255):`, JSON.stringify(counts, null, 0));
console.log(`tiles with u8+16 != 255: ${feat16.length}`);
console.log(feat16.slice(0, 60).map(t => `(${t.x},${t.y})=${t.v}`).join(' '));