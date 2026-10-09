// Byte-level decode of specific plots + global flag census.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');

const [,, savePath] = process.argv;
const bin = decompress(fs.readFileSync(savePath));
const searchBuffer = Buffer.from([0x0E,0x00,0x00,0x00, 0x0F,0x00,0x00,0x00, 0x06,0x00,0x00,0x00]);
const mapstart = bin.indexOf(searchBuffer);
const tiles = bin.readInt32LE(mapstart + 12);
const W = {1144:44,2280:60,3404:74,4536:84,5760:96,6996:106}[tiles] || 60;

const meta = [];
let m = mapstart + 16;
const census = { num: 0, num2: 0, both: 0, neither: 0 };
for (let i = 0; i < tiles; i++) {
  const num2 = bin.readUInt8(m + 49);
  const num = bin.readUInt32LE(m + 51);
  let bl = 0;
  if (num) bl += 24;
  if (num2 >= 64) bl += 17;
  meta.push({ off: m, len: 55 + bl, num2, num });
  if (num && num2 >= 64) census.both++;
  else if (num) census.num++;
  else if (num2 >= 64) census.num2++;
  else census.neither++;
  m += 55 + bl;
}
console.log(`save=${savePath.split('/').pop()} tiles=${tiles} census: num=${census.num} num2only=${census.num2} both=${census.both} none=${census.neither}`);

function show(x, y, label) {
  const t = meta[y * W + x];
  if (!t) return console.log(label, 'OOB');
  const b = bin;
  const hex = b.slice(t.off, t.off + Math.min(t.len, 96)).toString('hex');
  // decode per walker fields
  const f = {
    i16_0: b.readInt16LE(t.off), i16_2: b.readInt16LE(t.off+2),
    i16_4: b.readInt16LE(t.off+4), i16_6: b.readInt16LE(t.off+6),
    i16_8: b.readInt16LE(t.off+8), i16_10: b.readInt16LE(t.off+10),
    i32_12: b.readInt32LE(t.off+12).toString(16), i32_16: b.readInt32LE(t.off+16).toString(16),
    i16_20: b.readInt16LE(t.off+20), i32_22: b.readInt32LE(t.off+22).toString(16),
    i8_26: b.readUInt8(t.off+26), i32_27: b.readInt32LE(t.off+27).toString(16),
    i16_31: b.readInt16LE(t.off+31), i32_33: b.readInt32LE(t.off+33).toString(16),
    i8_37: b.readUInt8(t.off+37), i8_38: b.readUInt8(t.off+38), i8_39: b.readUInt8(t.off+39),
    i16_40: b.readInt16LE(t.off+40), i8_42: b.readUInt8(t.off+42), i8_43: b.readUInt8(t.off+43), i8_44: b.readUInt8(t.off+44),
    i8_45: b.readUInt8(t.off+45), i8_46: b.readUInt8(t.off+46), i8_47: b.readInt8(t.off+47),
    i8_48: b.readUInt8(t.off+48), i8_49: b.readUInt8(t.off+49), i8_50: b.readUInt8(t.off+50),
    num: t.num, num2: t.num2,
  };
  console.log(`\n-- ${label} (${x},${y}) off=${t.off} len=${t.len}`);
  console.log('hex:', hex);
  console.log('dec:', JSON.stringify(f));
}

show(0, 0, 'ocean NW (0,0)');
show(0, 6, 'ocean (0,6)');
show(3, 18, 'Islandia tundra (3,18)');
show(57, 39, 'CAPITAL (57,39)');
show(30, 48, 'South continent (30,48)');
show(55, 38, 'Lyse anchor (55,38)');
show(55, 37, 'Lyse anchor2 (55,37)');