// Walk-end + census test on OUR saves (Aspyr).
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);
const files = process.argv.slice(2);
for (const savePath of files) {
  const bin = decompress(fs.readFileSync(savePath));
  const mapstart = bin.indexOf(searchBuffer);
  const tiles = bin.readInt32LE(mapstart + 12);
  const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;
  let m = mapstart + 16;
  let num1 = 0, n2ge64 = 0, both = 0, neither = 0, oob = 0;
  const lenHist = {};
  for (let i = 0; i < tiles; i++) {
    const num2 = bin.readUInt8(m + 49);
    const num = bin.readUInt32LE(m + 51);
    if (num) num1++;
    if (num2 >= 64) n2ge64++;
    if (num && num2 >= 64) both++;
    if (!num && num2 < 64) neither++;
    const L = 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
    lenHist[L] = (lenHist[L] || 0) + 1;
    if (m + L + 55 > bin.length) oob++;
    m += L;
  }
  const after = bin.slice(m, m + 40).toString('hex');
  const ascafter = bin.slice(m, m + 48).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
  console.log(`\n=== ${savePath.split('/').pop()} ===`);
  console.log(`bin=${bin.length} mapSig@0x${mapstart.toString(16)} tiles=${tiles} W=${W}`);
  console.log(`census num=${num1} n2ge64=${n2ge64} both=${both} neither=${neither} oob=${oob}`);
  console.log(`lenHist=${JSON.stringify(lenHist)}`);
  console.log(`walkEnd=0x${m.toString(16)} (${Math.round(100 * m / bin.length)}% of bin)`);
  console.log(`after: ${after}`);
  console.log(`asc:   ${ascafter}`);
}