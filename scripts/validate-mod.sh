#!/usr/bin/env bash
# Validate a Civ 6 map-script mod source before deploy: luac -p for Lua files,
# xmllint --noout for XML files, and a GENERIC blueprint lint that derives the
# blueprint dimensions + legend from the detected Maps/*.lua itself:
#   - grid Width/Height from GetMapInitData
#   - cell scale from XLOC()/YLOC()
#   - legend chars from the RasterizeBlueprint cellType table
#   - rows extracted from the g_BLUEPRINT table block
# The Vinterhav mod (default) validates with this same generic path.
# Usage: validate-mod.sh [path-to-mod-dir]   (default ../Vinterhav)
. "$(dirname "$0")/common.sh"

MOD="${1:-$LOCAL_ROOT/Vinterhav}"
[ -d "$MOD" ] || { echo "mod dir not found: $MOD"; exit 1; }

echo "=== luac -p check ==="
for lua in "$MOD"/Maps/*.lua "$MOD"/Gameplay/*.lua; do
  [ -f "$lua" ] && { luac -p "$lua" && echo "OK $lua" || echo "Lua syntax FAIL $lua"; }
done

echo "=== xmllint check ==="
for x in "$MOD"/*.modinfo "$MOD"/Configuration/*.xml; do
  xmllint --noout "$x" && echo "OK $x"
done

echo "=== blueprint row validation ==="
python3 - "$MOD" << 'PYEOF'
import re, sys, pathlib
mod = pathlib.Path(sys.argv[1])
maps = sorted(mod.glob("Maps/*.lua"))
if not maps:
    print("SKIP — no map Lua found under Maps/")
    sys.exit(0)
p = maps[0]
text = p.read_text()
# drop inline comments so rows carrying -- notes are still validated
text = re.sub(r'--.*$', '', text, flags=re.M)

# --- derive grid + cell scale ---
m = re.search(
    r'function\s+GetMapInitData[^\{]*\{\s*Width\s*=\s*(\d+),\s*Height\s*=\s*(\d+)',
    text)
if not m:
    print("SKIP — cannot derive Width/Height from GetMapInitData")
    sys.exit(0)
width, height = int(m.group(1)), int(m.group(2))
sx = re.search(r'function\s+XLOC\(c\)\s+return\s+(\d+)\s*\*', text)
sy = re.search(r'function\s+YLOC\(r\)\s+return\s+(\d+)\s*\*', text)
scale_x = int(sx.group(1)) if sx else 1
scale_y = int(sy.group(1)) if sy else 1
if width % scale_x or height % scale_y:
    print(f"FAIL — grid {width}x{height} not divisible by cell {scale_x}x{scale_y}")
    sys.exit(1)
cols, rows = width // scale_x, height // scale_y

# --- legend chars = keys of the RasterizeBlueprint cellType table ---
leg = set(re.findall(r'\["([^"]{1})"\]\s*=\s*g_PLOT_TYPE_', text))
leg_str = "".join(sorted(leg))
print(f"derived: {cols} cols x {rows} rows (grid {width}x{height}, cell {scale_x}x{scale_y}), legend [{leg_str}]")

# --- extract the blueprint block ---
bm = re.search(r'local\s+g_BLUEPRINT\s*=\s*\{(.*?)\};', text, re.S)
if not bm:
    print("SKIP — no g_BLUEPRINT table found")
    sys.exit(0)
rows_found = re.findall(r'^\s*["\']([^"\']+)["\'],?\s*$', bm.group(1), re.M)
print(f"{len(rows_found)} rows matched (expect {rows})")
for i, r in enumerate(rows_found):
    assert len(r) == cols, f"row {i} wrong length {len(r)} != {cols}: {r!r}"
    bad = set(r) - leg
    assert not bad, f"row {i} bad legend chars: {bad}"
assert len(rows_found) == rows, f"expected {rows} blueprint rows, found {len(rows_found)}"
print("all rows correct length, legend chars valid")
PYEOF