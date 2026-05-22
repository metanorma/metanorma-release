# 03 — Delete .metanorma/channels.yml from 55 CalConnect repos

## Problem
55 CalConnect repos have `.metanorma/channels.yml` that is dead code.
The gem never reads these files. They create confusion about the architecture.

## Approach
Script-based cleanup via GitHub API:
1. Find all repos with `.metanorma/channels.yml`
2. Create branch `chore/remove-dead-channels-yml`
3. Delete `.metanorma/channels.yml` (and `.metanorma/` dir if empty)
4. Commit, push, create PR

## Repo list (55 repos)
Found via: `find /Users/mulgogi/src/calconnect -maxdepth 3 -name "channels.yml"`

## Status
- [x] Script written — `03-cleanup-repos.sh`
- [x] Dry run verified — 54 repos found
- [x] Run on all repos — 53 branches pushed, 53 PRs created, all 53 rebase-merged
