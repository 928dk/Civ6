#!/usr/bin/env bash
# Show which maps Civ6 currently has registered in its (GlobalCacheLoc)/DebugConfiguration.sqlite
# and list the contents of the WorldBuilder install of maps (WorldBuilderOnly=0) for cross-reference.
. "$(dirname "$0")/common.sh"

DB='"$HOME/.local/share/aspyr-media/Sid Meier'"'"'s Civilization VI/Cache/DebugConfiguration.sqlite"'
CMD='if [ -f '$DB' ]; then
  sqlite3 '$DB' "SELECT Domain, File, Description, DisableWorldWrap, WorldBuilderOnly FROM Maps ORDER BY File;" 2>/dev/null || echo "sqlite3 failed (check path/quoting)"
else
  echo "DebugConfiguration.sqlite not found (generated after first game run)"
fi'
ssh_vd "$CMD"