// Test num-as-count hypothesis + num histogram in the aligned prefix on OUR saves,
// and calibrate feature/terrain offsets on the CLEAN-walking Deity3 sample.
const fs = require('fs');
const { decompress } = require('../lib/decompress.js');
const searchBuffer = Buffer.from([0x0E, 0x00, 0x00, 0x00, 0x0F, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x00]);

// ---- Part 1: num-as-count walk-end test on our saves ----
for (const savePath of process.argv.slice(2)) {
  const bin = decompress(fs.readFileSync(savePath));
  const ms = bin.indexOf(searchBuffer);
  const tiles = bin.readInt32LE(ms + 12);
  let numGe2 = 0;
  const numPrefixHist = {};
  // two parallel walks: bool model vs count model (clamped)
  let mB = ms + 16, mC = ms + 16;
  let cExpl = 0;
  for (let i = 0; i < tiles && mC < bin.length; i++) {
    const num2B = bin.readUInt8(mB + 49);
    const numB_ = bin.readUInt32LE(mB + 51);
    if (i < 400) numPrefixHist[numB_] = (numPrefixHist[numB_] || 0) + 1;
    if (numB_ > 1) numGe2++;
    let numC_ = 0;
    if (mC + 55 <= bin.length) {
      num2C = bin.readUInt8(mC + 49);
      numC_ = bin.readUInt32LE(mC + 51);
    }
    if (numC_ > 16) { numC_ = 0; cExpl++; }
    mB += 55 + (numB_ ? 24 : 0) + (num2B >= 64 ? 17 : 0);
    mC += 55 + 24 * numC_ + (num2C >= 64 ? 17 : 0);
  }
  const afterB = bin.slice(mB, mB + 16).toString('hex');
  const afterC = bin.slice(mC, mC + 16).toString('hex');
  console.log(`\n=== ${savePath.split('/').pop()} ===`);
  console.log(`num>1 tiles (bool-walk): ${numGe2}/4536`);
  console.log(`num prefix hist (first 400): ${JSON.stringify(numPrefixHist)}`);
  console.log(`bool-walk end 0x${mB.toString(16)} after: ${afterB}`);
  console.log(`count-walk end 0x${mC.toString(16)} after: ${afterC}`);
}

// ---- Part 2: calibrate offsets on Deity3 (clean) ----
{
  const bin = decompress(fs.readFileSync('../samples/Deity3.Civ6Save'));
  const ms = bin.indexOf(searchBuffer);
  const tiles = bin.readInt32LE(ms + 12);
  const W = { 1144: 44, 2280: 60, 3404: 74, 4536: 84, 5760: 96, 6996: 106 }[tiles] || 60;
  let m = ms + 16;
  const hist12u32 = {}, hist16u32 = {}, hist22u32 = {}, hist26u8 = {}, hist31u16 = {}, hist33u32 = {}, hist37u8 = {}, hist45 = {};
  const val12 = [], val16 = [], val26 = [], val31 = [], val37 = [];
  let n2ge64 = 0, numv = 0;
  for (let i = 0; i < tiles; i++) {
    const num2 = bin.readUInt8(m + 49);
    const num = bin.readUInt32LE(m + 51);
    if (num) numv++; if (num2 >= 64) n2ge64++;
    const v12 = bin.readUInt32LE(m + 12), v16 = bin.readUInt32LE(m + 16), v22 = bin.readUInt32LE(m + 22);
    const v26 = bin.readUInt8(m + 26), v31 = bin.readUInt16LE(m + 31), v33 = bin.readUInt32LE(m + 33);
    const v37 = bin.readUInt8(m + 37), v45 = bin.readUInt8(m + 45);
    hist12u32[v12] = (hist12u32[v12] || 0) + 1; hist16u32[v16] = (hist16u32[v16] || 0) + 1;
    hist22u32[v22] = (hist22u32[v22] || 0) + 1; hist26u8[v26] = (hist26u8[v26] || 0) + 1;
    hist31u16[v31] = (hist31u16[v31] || 0) + 1; hist33u32[v33] = (hist33u32[v33] || 0) + 1;
    hist37u8[v37] = (hist37u8[v37] || 0) + 1; hist45[v45] = (hist45[v45] || 0) + 1;
    val12.push(v12); val16.push(v16); val26.push(v26); val31.push(v31); val37.push(v37);
    m += 55 + (num ? 24 : 0) + (num2 >= 64 ? 17 : 0);
  }
  const top = (h, n = 8) => Object.entries(h).sort((a, b) => b[1] - a[1]).slice(0, n).map(([k, c]) => `${k}:${c}`).join(' ');
  console.log(`\n=== Deity3 calibration (tiles=${tiles} W=${W}, num=${numv}, owns=${n2ge64}) ===`);
  console.log('u32+12 top:', top(hist12u32));
  console.log('u32+16 top:', top(hist16u32));
  console.log('u32+22 top:', top(hist22u32));
  console.log('u8+26 top:', top(hist26u8, 16));
  console.log('u16+31 top:', top(hist31u16, 16));
  console.log('u32+33 top:', top(hist33u32));
  console.log('u8+37 top:', top(hist37u8, 16));
  console.log('u8+45 top:', top(hist45, 16));
}