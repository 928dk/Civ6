// Dump the plot array of a .Civ6Save to TSV using lucienmaloney's decompress.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath, outPath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));

const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
if (mapstart < 0) { console.error('map signature not found'); process.exit(1); }
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;
const H = tiles / W;

const lines = [];
lines.push(['i','x','y','terrain32_12','feature32_16','int8_12_19_hex','i16_20','terrain2_22_hex','i8_26','res32_27','resbool_31','goody33_hex','i8_37','road_38','i8b_39','appeal_40','i8c_42','i8d_43','i8e_44','river_45','rivermap_46','cliff_47','q9_48_hex','num2_49','num_51','buflen','buf_hex'].join('\t'));

let m = mapstart + 16;
for (let i = 0; i < tiles; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  let bl = 0;
  if (num) bl += 24;
  if (num2 >= 64) bl += 17;
  const row = [
    i, i % W, Math.floor(i / W),
    bin.readInt32LE(m + 12),
    bin.readInt32LE(m + 16),
    bin.slice(m + 12, m + 20).toString('hex'),
    bin.readInt16LE(m + 20),
    bin.slice(m + 22, m + 26).toString('hex'),
    bin.readUInt8(m + 26),
    bin.readUInt32LE(m + 27),
    bin.readInt16LE(m + 31),
    bin.slice(m + 33, m + 37).toString('hex'),
    bin.readUInt8(m + 37), bin.readUInt8(m + 38), bin.readUInt8(m + 39),
    bin.readInt16LE(m + 40),
    bin.readUInt8(m + 42), bin.readUInt8(m + 43), bin.readUInt8(m + 44),
    bin.readUInt8(m + 45), bin.readUInt8(m + 46), bin.readInt8(m + 47),
    bin.slice(m + 48, m + 51).toString('hex'),
    num2, num, bl,
    bin.slice(m + 55, m + 55 + bl).toString('hex'),
  ];
  lines.push(row.join('\t'));
  m += 55 + bl;
}
fs.writeFileSync(outPath, lines.join('\n'));
console.log(`wrote ${outPath}: ${tiles} tiles (${W}x${H}), map section end 0x${m.toString(16)}, trailing ${bin.length - m}`);