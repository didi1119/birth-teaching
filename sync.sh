#!/usr/bin/env bash
# Sync full_deck.html (merged lead-in + main course) + all referenced images
# from multiple source folders to this deploy folder, flatten paths, then push
# to GitHub. Also publishes the speaker script cheatsheet at /cheatsheet.html.
#
# Live URL: https://didi1119.github.io/birth-teaching/
set -euo pipefail

PROJECT_ROOT="/Users/kobee/Documents/New project 4"
DECK_SRC="$PROJECT_ROOT/deck_output/html_ai_toolbox_integrated/full_deck.html"
CHEATSHEET_SRC="$PROJECT_ROOT/deck_output/speaker_script_cheatsheet.html"
DEPLOY_DIR="$PROJECT_ROOT/deploy_birth_teaching"

if [ ! -f "$DECK_SRC" ]; then
  echo "ERROR: source deck not found at $DECK_SRC" >&2
  exit 1
fi

cd "$DEPLOY_DIR"

# Clean old images (keep .git, sync.sh, README, HTML files)
find . -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" -o -name "*.svg" \) -delete

# Use Python for robust path resolution + HTML path rewriting
python3 <<PYEOF
import re, shutil, os
from pathlib import Path

deck_src = Path("$DECK_SRC")
cheat_src = Path("$CHEATSHEET_SRC")
deploy = Path("$DEPLOY_DIR")

# --- Process full_deck.html ---
html = deck_src.read_text(encoding='utf-8')
src_dir = deck_src.parent

# Find all src="..." image references
img_pat = re.compile(r'src="([^"]+\.(?:png|jpg|jpeg|gif|webp|svg))"')
refs = sorted(set(img_pat.findall(html)))

print(f"Found {len(refs)} image references in full_deck.html")
copied, missing = 0, []
seen_bases = {}

for ref in refs:
    # Resolve relative to the source HTML location
    abs_path = (src_dir / ref).resolve()
    if not abs_path.exists():
        missing.append(ref)
        continue
    base = abs_path.name
    # Handle name collisions (different files, same basename)
    if base in seen_bases and seen_bases[base] != str(abs_path):
        # Prefix with parent folder name to disambiguate
        base = f"{abs_path.parent.name}__{base}"
    seen_bases[base] = str(abs_path)
    # Copy to deploy folder
    shutil.copy2(abs_path, deploy / base)
    # Rewrite path in HTML to flat basename
    html = html.replace(f'src="{ref}"', f'src="{base}"')
    copied += 1

print(f"Copied {copied} images")
if missing:
    print(f"MISSING ({len(missing)}):")
    for m in missing:
        print(f"  - {m}")

# Write rewritten deck as index.html
(deploy / "index.html").write_text(html, encoding='utf-8')

# --- Copy cheatsheet as cheatsheet.html (no image rewriting needed; it's text-only) ---
if cheat_src.exists():
    cheat_html = cheat_src.read_text(encoding='utf-8')
    (deploy / "cheatsheet.html").write_text(cheat_html, encoding='utf-8')
    print("Copied cheatsheet.html")
PYEOF

cd "$DEPLOY_DIR"

# Commit + push if there are changes
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git -c user.email="ai@washinmura.jp" -c user.name="didi1119" \
    commit -m "sync: deploy full deck (lead-in + main) $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "✓ Synced and pushed. GitHub Pages rebuilds in ~30s:"
  echo "  Deck:       https://didi1119.github.io/birth-teaching/"
  echo "  Cheatsheet: https://didi1119.github.io/birth-teaching/cheatsheet.html"
else
  echo "No changes to sync."
fi
