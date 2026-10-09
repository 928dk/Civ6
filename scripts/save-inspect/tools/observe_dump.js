// Dump ALL observing-list positions for team 0 + render; then hunt the fog bitmap in the tail.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const W = 84, T = 4536;
// team 0 layout (verified):
const observingStart = 0x1c78;
const bdbStart = 0xaa90;

function positions(listStart, label) {
  const pts = [];
  for (let i = 0; i < T; i++) {
    const v = bin.readUInt16LE(listStart + i * 2);
    if (v) pts.push({ i, v, x: i % W, y: Math.floor(i / W) });
  }
  console.log(`${label}: ${pts.length} entries`);
  console.log('  ' + pts.map(p => `(${p.x},${p.y})v${p.v}`).join(' '));
  return pts;
}

const obs = positions(observingStart, 'observing (team0)');
const bdb = positions(bdbStart, 'bdbef3c1 (team0)');

function render(pts, name) {
  const grid = Array.from({ length: 54 }, () => new Array(84).fill('.'));
  for (const p of pts) grid[p.y][p.x] = '#';
  console.log(`\n${name} map (84x54):`);
  for (let y = 0; y < 54; y++) console.log(String(y).padStart(2) + ' ' + grid[y].join(''));
}
render(obs, 'observing');
render(bdb, 'bdbef3c1');

// centroid of observing
if (obs.length) {
  const cx = Math.round(obs.reduce((a, p) => a + p.x, 0) / obs.length);
  const cy = Math.round(obs.reduce((a, p) => a + p.y, 0) / obs.length);
  console.log(`observing centroid (~${cx},~${cy})`);
}
if (bdb.length) {
  const cx = Math.round(bdb.reduce((a, p) => a + p.x, 0) / bdb.length);
  const cy = Math.round(bdb.reduce((a, p) => a + p.y, 0) / bdb.length);
  console.log(`bdbef3c1 centroid (~${cx},~${cy})`);
}

// fog bitmap hunt in the tail region (0xce10..0xdfd1): find 567-byte windows with sparse bits
console.log('\nfog hunt in team0 tail:');
function fogScore(off) {
  // plausible: mostly zeros; count nonzero bytes; and bits should cluster
  let nz = 0;
  for (let b = 0; b < 567; b++) if (bin[off + b]) nz++;
  return nz;
}
let best = [];
for (let off = 0x1c60; off < 0x1c60 + 50029 - 567; off += 1) {
  const s = fogScore(off);
  if (s > 0 && s < 600) best.push({ off, s });
}
best.sort((a, b) => a.s - b.s);
console.log('windows with 0-600 nonzero bytes (first 20 by score):');
for (const b of best.slice(0, 20)) console.log(`  0x${b.off.toString(16)} nz=${b.s}`);
// Also on the RAW bin head: search whole bin for 4536-value + fog pattern:
// [b8110000][fog 567] appearing anywhere
const cand = [];
const tilesBuf = Buffer.from([0xb8, 0x11, 0x00, 0x00]);
let i = 0;
while ((i = bin.indexOf(tilesBuf, i)) !== -1 && cand.length < 30) { cand.push(i); i += 4; }
console.log('\nall 4536-int32 occurrences:');
for (const c of cand) {
  // what follows?
  const after = bin.slice(c + 4, c + 4 + 8).toString('hex');
  const asc = bin.slice(c + 4, c + 4 + 8).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
  console.log(`  0x${c.toString(16)}: after=${after} asc=${asc}`);
}