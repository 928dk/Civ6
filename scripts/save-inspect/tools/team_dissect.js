// Team-0 block layout dissection: nonzero-byte profile across the whole span.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const team0start = 0x1c60;            // [05] of observing header
const team1start = 0xdfd1;            // next team's observing head
const span = team1start - team0start; // 50029

// scan bytes: mark zero vs nonzero, print a run-length summary
let runs = [];
let cur = null;
for (let p = team0start; p < team1start; p++) {
  const nz = bin[p] !== 0;
  if (cur && cur.nz === nz) cur.len++;
  else { cur = { p, nz, len: 1 }; runs.push(cur); }
}
console.log('team0 span', span);
let out = [];
for (const r of runs) {
  out.push(`${r.nz ? 'NZ' : '00'}@0x${r.p.toString(16)}+${r.len}`);
}
console.log(out.join(' | '));

// precise nonzero window analysis: for each of the known sections, count nonzero u16s (reading as u16)
const sections = [
  ['observing', 0x1c78, 0x3ff0],
  ['modifiers(f7)', 0x4004, 0x6374],
  ['resources(d1)', 0x6388, 0x86f8],
  ['roads(a8)', 0x870c, 0xaa7c],
  ['bdbef3c1-list', 0xaa90, 0xce10],
  ['tail', 0xce10, 0xdfd1],
];
for (const [name, s, e] of sections) {
  let nzWords = 0, nzBytes = 0, minV = 65535, maxV = 0;
  for (let p = s; p + 1 < e; p += 2) {
    const v = bin.readUInt16LE(p);
    if (v) { nzWords++; if (v < minV) minV = v; if (v > maxV) maxV = v; }
  }
  for (let p = s; p < e; p++) if (bin[p]) nzBytes++;
  console.log(`${name}: len=${e - s} nzWords=${nzWords} nzBytes=${nzBytes} minV=${minV} maxV=${maxV}`);
  // show first 8 nonzero words' positions
  if (nzWords > 0) {
    const pts = [];
    for (let p = s; p + 1 < e && pts.length < 8; p += 2) {
      const v = bin.readUInt16LE(p);
      if (v) pts.push(`tile${Math.floor((p - s) / 2)}:${v}`);
    }
    console.log(`   first nz: ${pts.join(' ')}`);
  }
}

// Check the SPACING table for all teams
console.log('\nteam spacing check:');
const m26 = Buffer.from([0x26, 0x10, 0x35, 0x11]);
let i = 0; const idxs = [];
while ((i = bin.indexOf(m26, i)) !== -1 && idxs.length < 25) { idxs.push(i); i += 1; }
for (let t = 1; t < idxs.length; t++) console.log(`t${t} @0x${idxs[t].toString(16)} spacing from prev: ${idxs[t] - idxs[t - 1]}`);