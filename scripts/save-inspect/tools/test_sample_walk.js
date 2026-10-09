// Test the repo walker model on the repo's own sample saves (and ours).
// Measures: does walking all tiles end exactly at a plausible next-section boundary?
const fs = require('fs');
const path = require('path');
const { decompress } = require('../lib/decompress.js');

const samplesDir = '../samples';
const files = fs.readdirSync(samplesDir).filter(f => f.endsWith('.Civ6Save'));

const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);

for (const f of files) {
  const savePath = path.join(samplesDir, f);
  let bin;
  try { bin = decompress(fs.readFileSync(savePath)); } catch (e) { console.log(f, 'DECOMPRESS FAIL', e.message); continue; }
  const mapstart = bin.indexOf(searchBuffer);
  if (mapstart < 0) { console.log(f, 'no map sig'); continue; }
  const tiles = bin.readInt32LE(mapstart + 12);
  const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;
  let m = mapstart + 16;
  let num1 = 0, n2ge64 = 0, both = 0, neither = 0;
  let oob = 0;
  for (let i = 0; i < tiles; i++) {
    const num2 = bin.readUInt8(m + 49);
    const num = bin.readUInt32LE(m + 51);
    if (num) num1++;
    if (num2 >= 64) n2ge64++;
    if (num && num2 >= 64) both++;
    if (!num && num2 < 64) neither++;
    const L = 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
    if (m + L + 55 > bin.length) oob++;
    m += L;
  }
  // what's at the walk end?
  const after = bin.slice(m, m + 32).toString('hex');
  const ascafter = bin.slice(m, m + 40).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
  console.log(`\n=== ${f} ===`);
  console.log(`binSize=${bin.length} mapSig@0x${mapstart.toString(16)} tiles=${tiles} W=${W}`);
  console.log(`census num=${num1} num2ge64=${n2ge64} both=${both} neither=${neither} oob=${oob}`);
  console.log(`walkEnd=0x${m.toString(16)} (bin 0x${bin.length.toString(16)} = ${Math.round(100 * m / bin.length)}%)`);
  console.log(`after: ${after}  asc: ${ascafter}`);
}