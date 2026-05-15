# 05 — Channel Manifest

## Summary

Implement `ChannelManifest` — the parser for `metanorma.release.yml` that declares per-document release policy (visibility, channels, stage allow-lists). This is the configuration layer that determines how documents are published.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (Channel, ChannelAudience)

## Creates

```
lib/metanorma/release/
└── channel_manifest.rb

spec/release/
└── channel_manifest_spec.rb
spec/fixtures/
└── manifests/
    ├── minimal.yml
    ├── full.yml
    ├── pattern_matching.yml
    └── malicious.yml
```

## Design Principles

### Manifest is a policy engine, not just config
The manifest resolves a document to a `DocumentReleasePolicy` (should it be released? to which channels? at which stages?). This is pure domain logic — no I/O beyond parsing YAML.

### Pattern matching with priority
Documents can be matched by exact `source` path (priority 100) or glob `pattern` (priority 50 + pattern length). First match wins, no ambiguity.

### Security: path traversal protection
Reject `source` entries containing `..`. Fail fast on malicious input.

---

## ChannelManifest

```ruby
class Metanorma::Release::ChannelManifest
  # Construction
  def self.parse(yaml_hash)              # From parsed YAML
  def self.from_file(path)               # Read + parse YAML file
  def self.all_public                     # Manifest that releases everything publicly
  def self.all_private                    # Manifest that releases nothing

  # Resolution
  def resolve(document)                  # => DocumentReleasePolicy
  def list_all                           # => [ManifestEntry]

  # Query
  def all_channels                       # => [Channel] (deduplicated)
  def explicit?                          # Was loaded from a file (vs default)?
end
```

## DocumentReleasePolicy

```ruby
class Metanorma::Release::DocumentReleasePolicy
  def self.from_defaults(visibility, channels)  # For unlisted documents
  def self.from_entry(entry)                    # From a manifest entry
  def self.not_released                         # Private document

  def release?                         # Should this document be released?
  def channels                         # [Channel]
  def stage_allow_list                 # Set<String> or nil (nil = all stages)
end
```

## ManifestEntry

```ruby
class Metanorma::Release::ManifestEntry
  def source                           # String? (exact file path)
  def pattern                          # String? (glob pattern)
  def visibility                       # "public", "private", "members"
  def channels                         # [Channel]
  def stages                           # [String]? (stage allow-list)
end
```

## YAML Format

```yaml
defaults:
  visibility: public
  channels:
    - public/standards

documents:
  - source: sources/cc-19060.adoc
    channels:
      - public/standards
      - public/public-review

  - source: sources/cc-19060-draft.adoc
    visibility: members
    channels:
      - members/drafts
    stages: [working-draft, committee-draft]

  - pattern: "cc-*"
    channels:
      - public/standards
```

### Resolution behavior (ported from TS `ChannelManifest.resolve`):

1. If manifest was NOT explicitly loaded (`all_public` / `all_private`): return default policy
2. Find best matching entry (exact source > glob pattern, longest pattern wins)
3. If no match: use manifest-level defaults
4. If no defaults in manifest: treat unlisted documents as **private** (safe default)

### Path traversal protection:
- Reject `source` entries containing `..`
- Reject duplicate sources (warn, use last entry)

### Specs

**Parsing**:
- Minimal manifest (defaults only, no documents)
- Full manifest with multiple documents
- Pattern matching manifest
- Manifest with malformed YAML raises clear error
- Manifest with `..` in source raises path traversal error

**Resolution**:
- Exact source match takes priority over pattern
- Pattern match selects longest matching pattern
- Unlisted document uses defaults
- Unlisted document is private when no defaults specified
- Document matched by pattern inherits pattern's channels
- `all_public` releases everything with `public/default` channel
- `all_private` releases nothing

**Channel resolution**:
- Explicit channels override visibility-derived channels
- No channels + visibility=public → `[Channel.public("default")]`
- No channels + visibility=members → `[Channel.members("default")]`
- No channels + visibility=private → `[]` (not released)

**Stage allow-list**:
- `stages: [working-draft]` → stage_allow_list = Set["working-draft"]
- No `stages` → nil (all stages allowed)
- Empty `stages` → nil (all stages allowed)

**Security**:
- `source: "../../etc/passwd"` raises error
- Duplicate sources produce warning

---

## Acceptance

- [ ] Parse all valid manifest formats
- [ ] Resolve policies correctly for exact match, pattern match, and default
- [ ] Reject path traversal
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
