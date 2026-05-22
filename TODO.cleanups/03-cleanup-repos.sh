#!/bin/bash
# Delete .metanorma/channels.yml (and .metanorma/ dir) from CalConnect repos.
# Usage: bash TODO.cleanups/03-cleanup-repos.sh [--dry-run]
#
# This removes dead config files — the gem never reads per-repo channels.yml.

set -uo pipefail

DRY_RUN=false
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=true

BRANCH="chore/remove-dead-channels-yml"
COMMIT_MSG="chore: remove dead .metanorma/channels.yml

The metanorma-release gem never reads per-repo .metanorma/channels.yml.
Channel routing is configured in metanorma.release.yml via documents[]
entries. This file was dead code that created confusion about the
architecture."

count=0
skipped=0

for channels_file in $(find /Users/mulgogi/src/calconnect -maxdepth 3 -name "channels.yml" -path "*/.metanorma/*" 2>/dev/null | sort); do
  metanorma_dir=$(dirname "$channels_file")
  repo_dir=$(dirname "$metanorma_dir")
  repo_name=$(basename "$repo_dir")

  # Skip the org config repo
  if [[ "$repo_name" == "dot-metanorma" ]]; then
    echo "SKIP: $repo_name (org config repo — handle separately)"
    skipped=$((skipped + 1))
    continue
  fi

  count=$((count + 1))

  if $DRY_RUN; then
    echo "DRY: $repo_name — would remove $channels_file"
    continue
  fi

  cd "$repo_dir"

  # Check for uncommitted changes
  if ! git diff --quiet HEAD 2>/dev/null; then
    echo "SKIP: $repo_name — uncommitted changes"
    continue
  fi

  # Create branch from main
  git checkout main -q 2>/dev/null
  git pull -q 2>/dev/null || true
  git checkout -b "$BRANCH" -q 2>/dev/null || git checkout "$BRANCH" -q

  # Remove the file and directory
  rm -rf "$metanorma_dir"

  # Commit and push
  git add -A
  if git diff --cached --quiet; then
    echo "SKIP: $repo_name — no changes (already removed?)"
    git checkout main -q 2>/dev/null
    continue
  fi

  git commit -m "$COMMIT_MSG" -q
  git push -u origin "$BRANCH" -q 2>/dev/null

  # Create PR
  gh pr create \
    --title "chore: remove dead .metanorma/channels.yml" \
    --body "$COMMIT_MSG" \
    --base main \
    --head "$BRANCH" \
    2>/dev/null || echo "WARN: $repo_name — PR creation failed (may already exist)"

  git checkout main -q 2>/dev/null

  echo "DONE: $repo_name"
done

echo ""
echo "Processed: $count repos, skipped: $skipped"
if $DRY_RUN; then
  echo "(dry run — no changes made)"
fi
