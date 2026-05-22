# 02 — Update metanorma.org documentation

## Problem
Three documentation files still reference the old three-file architecture
(org config repo, per-repo channels.yml, org: key).

## Files to update

### `_pages/install/publication-setup.adoc`
- Remove org config repo section and channels.yml schema
- Remove `org:` key from config examples
- Remove `.metanorma/channels.yml` from file checklist
- Move `display_categories` into aggregator config schema
- Document two-file architecture: release manifest + aggregate config

### `_posts/2026-05-13-channel-based-publication.adoc`
- Remove `.metanorma/channels.yml` sections (lines 64-77, 124-130, 238-242)
- Remove CalConnect/.metanorma references (line 504)
- Update `display_category` reference (line 449) — now in aggregator config
- Reflect two-file architecture throughout

### `_pages/install/cicd.adoc`
- Remove "Channel discovery manifest" subsection (lines 476-483)
- Remove `channels.yml` from file tree (line 224)
- Remove `.metanorma/channels.yml` section (line 243)
- Remove org config references (lines 408-432)

## Status
- [x] publication-setup.adoc
- [x] blog post
- [x] cicd.adoc
