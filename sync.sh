#!/usr/bin/env bash
# Sync ai_toolbox_selection_deck.html + referenced images from source
# to this deploy folder, then push to GitHub (auto-rebuilds Pages).
set -euo pipefail

SRC_DIR="/Users/kobee/Documents/New project 4/deck_output/html_ai_toolbox_integrated"
DEPLOY_DIR="/Users/kobee/Documents/New project 4/deploy_birth_teaching"
SRC_HTML="$SRC_DIR/ai_toolbox_selection_deck.html"

if [ ! -f "$SRC_HTML" ]; then
  echo "ERROR: source HTML not found at $SRC_HTML" >&2
  exit 1
fi

cd "$DEPLOY_DIR"

# Remove old images (keep .git, sync.sh, README if any)
find . -maxdepth 1 -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.gif" -o -name "*.webp" -o -name "*.svg" \) -delete

# Copy latest HTML as index.html
cp "$SRC_HTML" "$DEPLOY_DIR/index.html"

# Copy only images referenced by the HTML
cd "$SRC_DIR"
grep -oE 'src="[^"]+\.(png|jpg|jpeg|gif|webp|svg)"' ai_toolbox_selection_deck.html \
  | sed -E 's/src="(.+)"/\1/' \
  | sort -u \
  | while read -r f; do
      [ -f "$f" ] && cp "$f" "$DEPLOY_DIR/$f"
    done

cd "$DEPLOY_DIR"

# Commit + push if there are changes
if [ -n "$(git status --porcelain)" ]; then
  git add .
  git -c user.email="ai@washinmura.jp" -c user.name="didi1119" \
    commit -m "sync: update deck from source $(date '+%Y-%m-%d %H:%M')"
  git push origin main
  echo ""
  echo "Synced and pushed. GitHub Pages will rebuild in ~30s:"
  echo "  https://didi1119.github.io/birth-teaching/"
else
  echo "No changes to sync."
fi
