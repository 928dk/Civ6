// Search for embedded image data (JPEG/PNG/DDS/BMP) in raw and decompressed saves.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const [, , savePath] = process.argv;

const raw = fs.readFileSync(savePath);
const bin = decompress(raw);

const sigs = [
  ['JPEG', Buffer.from([0xff, 0xd8, 0xff])],
  ['PNG', Buffer.from([0x89, 0x50, 0x4e, 0x47])],
  ['DDS', Buffer.from('DDS ')],
  ['BMP', Buffer.from('BM')],
  ['TGA', Buffer.from([0x0a, 0x00, 0x00, 0x00])],
  ['GIF', Buffer.from('GIF8')],
];
for (const [name, sig] of sigs) {
  for (const [label, buf] of [['raw', raw], ['bin', bin]]) {
    const idxs = [];
    let i = 0;
    while ((i = buf.indexOf(sig, i)) !== -1 && idxs.length < 5) { idxs.push(i); i += 1; }
    if (idxs.length) console.log(`${label} ${name}: ${idxs.map(i => '0x' + i.toString(16)).join(', ')}`);
  }
}

// Also: count PNG/JPEG barriers in big uneven regions (thumbnail could be at the very end of raw)
console.log('\nraw size', raw.length, 'bin size', bin.length);
console.log('raw last 64 bytes:', raw.slice(raw.length - 64).toString('hex'));
console.log('bin last 64 bytes:', bin.slice(bin.length - 64).toString('hex'));