// Grep decompressed save bins for feature-type strings + nearby context.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
console.log('bin size', bin.length);

const needles = ['LYSE', 'EYJA', 'CRATER', 'PIOPIOTAHI', 'YOSEMITE', 'FEATURE_', 'StartPlot', 'START_PLOT', 'Tiles', 'Terrain'];
for (const s of needles) {
  const idxs = [];
  let i = 0;
  while ((i = bin.indexOf(Buffer.from(s), i)) !== -1 && idxs.length < 8) { idxs.push(i); i += s.length; }
  if (idxs.length) {
    console.log(`\n${s}: ${idxs.map(i => '0x' + i.toString(16)).join(', ')}`);
    idxs.slice(0, 3).forEach(i => {
      console.log(`  ctx@0x${i.toString(16)}: ${bin.slice(Math.max(0, i - 48), i + 96).toString('hex')}`);
      const asc = bin.slice(Math.max(0, i - 32), i + 64).toString('latin1').replace(/[^\x20-\x7e]/g, '.');
      console.log(`  asc: ${asc}`);
    });
  }
}