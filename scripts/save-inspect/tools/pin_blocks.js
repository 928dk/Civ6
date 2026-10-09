// Pin team-block layout: dump around the observing section and the f7 boundary.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

function dumpHex(from, to, label) {
  console.log(`\n=== ${label} 0x${from.toString(16)}..0x${to.toString(16)} ===`);
  for (let off = from; off < to; off += 16) {
    const sl = bin.slice(off, Math.min(off + 16, to));
    const hex = sl.toString('hex').padEnd(32, ' ');
    const asc = sl.toString('latin1').replace(/[^\x20-\x7e]/g, '.');
    console.log(`0x${off.toString(16)}: ${hex}  ${asc}`);
  }
}

dumpHex(0x1b00, 0x1d20, 'before observing section');
dumpHex(0x3ec0, 0x4004, 'f7 marker + list tail');
dumpHex(0x1c6c + 0x10, 0x1c6c + 0x60, 'observing header detail');