// Locate team-block markers (f7a356cf / d180288f / a8a6f95c) and extract the
// human team's observing list (Tiles*2 Int16) + fog bitmap.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
console.log('bin size', bin.length);

const TILES = 4536;
const W = 84;
const LIST = TILES * 2;          // 9072 bytes per Int16 list

// little-endian 4-byte markers
const F7 = Buffer.from([0xf7, 0x56, 0xa3, 0xcf]);
const D1 = Buffer.from([0xd1, 0x80, 0x28, 0x8f]);
const A8 = Buffer.from([0xa8, 0xa6, 0xf9, 0x5c]);

function findMarker(marker) {
  const idxs = [];
  let i = 0;
  while ((i = bin.indexOf(marker, i)) !== -1 && idxs.length < 30) { idxs.push(i); i += 1; }
  return idxs;
}

const f7s = findMarker(F7);
const d1s = findMarker(D1);
const a8s = findMarker(A8);
console.log('f7a356cf at', f7s.map(i => '0x' + i.toString(16)).join(','));
console.log('d180288f at', d1s.map(i => '0x' + i.toString(16)).join(','));
console.log('a8a6f95c at', a8s.map(i => '0x' + i.toString(16)).join(','));

// For each f7 marker, verify: f7+4 (0x01), +8 count, +12 width, +16 count (all = TILES), then list
for (const f7 of f7s) {
  const sect1 = bin.readInt32LE(f7 + 4);
  const cnt1 = bin.readInt32LE(f7 + 8);
  const wid1 = bin.readInt32LE(f7 + 12);
  const cnt2 = bin.readInt32LE(f7 + 16);
  const listStart = f7 + 20;
  const next = listStart + LIST;
  const nextIsD1 = bin.slice(next, next + 4).equals(D1);
  const d1sec = bin.readInt32LE(next + 4);
  const cnt3 = bin.readInt32LE(next + 8);
  const wid3 = bin.readInt32LE(next + 12);
  const ok = (sect1 === 1 && cnt1 === TILES && wid1 === W && cnt2 === TILES && nextIsD1 && cnt3 === TILES && wid3 === W);
  console.log(`f7@0x${f7.toString(16)}: sect=${sect1} cnt=${cnt1} wid=${wid1} cnt2=${cnt2} -> next d1=${nextIsD1} cnt3=${cnt3} wid3=${wid3} OK=${ok}`);
}

// Build the skeleton for each *team* block by walking back from f7 markers:
// observing list start = f7 (its list occupies [f7+20 .. f7+20+9072])
// before that: [0x05][0x11351026][0x00][count][width][count] = 24 bytes, then observing list STARTS at f7 - 24
// hmm -- verify: the observing list is INSIDE the section that ends right before f7 header.
// Per doc: ...Fog bitmap... [0x05?][0x11351026?][0x00?][NumTiles][Width][NumTiles][Observing list][f7a356cf...]
// So: observingListStart = f7 - (24 + 9072)?? No: [f7 header is 20 bytes][modifiers 9072] -> so observing list ENDS at f7.
// observingListStart = f7 - 9072.
const obsStart = f7s[0] - LIST;
console.log(`\nobserving list of first team starts at 0x${obsStart.toString(16)}`);

// dump the observing list (values > 0 = something observing the tile)
const seen = { high: 0, zero: 0, max: 0 };
const nonzero = [];
for (let i = 0; i < TILES; i++) {
  const v = bin.readInt16LE(obsStart + i * 2);
  if (v > 0) { seen.high++; nonzero.push({ x: i % W, y: Math.floor(i / W), v }); if (v > seen.max) seen.max = v; }
  else seen.zero++;
}
console.log(`observing: zero=${seen.zero} nonzero=${seen.high} max=${seen.max}`);
console.log('nonzero coords:', nonzero.map(t => `(${t.x},${t.y})${t.v > 1 ? '*' + t.v : ''}`).join(' '));

// Render a coarse ASCII map of observed tiles
console.log('\nobserved-map (x:observed  .:not):');
for (let y = 0; y < 54; y++) {
  let row = '';
  for (let x = 0; x < W; x++) {
    const v = bin.readInt16LE(obsStart + (y * W + x) * 2);
    row += v > 0 ? 'x' : '.';
  }
  console.log(String(y).padStart(2) + ' ' + row);
}