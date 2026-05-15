# 03 — Stage & Version Model

## Summary

Implement `DocumentStage`, `DocumentVersion`, and `ReleaseTag` — the value objects that model a document's lifecycle stage and release identity.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (DocumentId used in ReleaseTag)

## Creates

```
lib/metanorma/release/
├── document_stage.rb
├── document_version.rb
└── release_tag.rb

spec/domain/
├── document_stage_spec.rb
├── document_version_spec.rb
└── release_tag_spec.rb
```

## Design Principles

### ISO stage mapping is domain logic
`DocumentStage.from_iso_stage(60, 00)` → `"published"`. This mapping is standardized (ISO/IEC Directives) and belongs in the domain model, not in a platform adapter.

### Stage determines naming
The stage suffix (empty for published, `-wd` for working-draft, etc.) affects release tag and file naming. This is a pure function of the stage — no I/O, no external state.

### Version is a composite value
`DocumentVersion` combines edition + stage. It's not an entity — it has no identity beyond its value. Two documents with the same edition and stage have the same version.

---

## DocumentStage

```ruby
class Metanorma::Release::DocumentStage
  PUBLISHED_NAMES = Set["published", "in-force", "approved", "standard"].freeze

  STAGE_ABBREVS = {
    "working-draft" => "wd",
    "committee-draft" => "cd",
    "draft-standard" => "ds",
    "final-draft" => "fd",
    "proposal" => "proposal",
    "informational" => "info",
    "withdrawn" => "withdrawn",
    "cancelled" => "cancelled"
  }.freeze

  # Construction
  def self.from_status(status_string)       # Normalize: "Working Draft" → "working-draft"
  def self.from_iso_stage(stage, substage)  # Numeric ISO stage mapping
  def self.published                        # Convenience: "published"
  def self.working_draft                    # Convenience: "working-draft"

  # Predicates
  def published?                            # In PUBLISHED_NAMES
  def draft?                                # Not published, not withdrawn, not cancelled
  def withdrawn?
  def cancelled?

  # Naming
  def tag_suffix                            # "" for published, "wd" for working-draft, etc.
  def to_s                                  # Normalized name: "working-draft"

  # Equality
  def eql?(other)
  def hash
end
```

ISO stage mapping (ported from TS):
- Stage 20 → working-draft
- Stage 30 → committee-draft
- Stage 40 → draft-standard
- Stage 50 → final-draft
- Stage 60 → published
- Stage 95 → withdrawn
- Default → working-draft

Normalization: lowercase, trim, collapse whitespace to `-`.

### Specs
- `from_status`: various cases — `"Published"`, `"WORKING DRAFT"`, `"committee-draft"`, `"In Force"`
- `from_status`: rejects empty string
- `from_iso_stage`: all defined stages (20, 30, 40, 50, 60, 95) + fallback
- `from_iso_stage`: stage 60.00, stage 60.60 (both published)
- `published?`: true for "published", "in-force", "approved", "standard"
- `draft?`: true for "working-draft", "committee-draft"; false for "published", "withdrawn"
- `tag_suffix`: empty for published, abbreviations for drafts
- Equality: same name → equal, different names → not equal

---

## DocumentVersion

```ruby
class Metanorma::Release::DocumentVersion
  # Construction
  def self.from(edition, stage)      # edition: String ("1"), stage: DocumentStage
  def self.published(edition:)       # Convenience: published stage

  # Accessors
  def edition                        # "1"
  def stage                          # DocumentStage
  def tag_component                  # "ed1" or "ed1-wd"
  def pre_release?                   # stage.draft?

  # Naming
  def file_name(doc_id)             # "cc-18011-ed1.zip" or "cc-18011-ed1-wd.zip"

  # Equality
  def eql?(other)
  def hash
end
```

Default edition is "0" when nil/blank. `tag_component` appends stage suffix only for non-published stages.

### Specs
- `from("1", DocumentStage.published)`: tag_component = "ed1", pre_release? = false
- `from("2", DocumentStage.from_status("working-draft"))`: tag_component = "ed2-wd", pre_release? = true
- `from(nil, ...)`: edition defaults to "0"
- `file_name`: combines doc_id + edition + stage suffix
- Equality: same edition + stage → equal

---

## ReleaseTag

```ruby
class Metanorma::Release::ReleaseTag
  # Construction
  def self.from(doc_id, version)     # DocumentId + DocumentVersion → "cc-18011/ed1"
  def self.create(tag, pre_release:) # Direct construction with validation
  def self.parse(tag)                # Parse "cc-18011/ed1" → ReleaseTag

  # Accessors
  def to_s                           # "cc-18011/ed1"
  def pre_release?                   # Derived from version stage or explicit flag
  def eql?(other)
  def hash
end
```

Format: `{doc_id}/{version_tag_component}`. The slash separator is mandatory — it distinguishes document ID from version. `parse` infers `pre_release?` from known stage suffixes in the version part.

Pre-release detection rules (ported from TS):
- Contains `-wd`, `-cd`, `-ds`, `-fd`, `-proposal` → pre-release

### Specs
- `from`: creates "cc-18011/ed1" from DocumentId + DocumentVersion
- `from`: creates "cc-18011/ed1-wd" for draft version
- `create`: requires slash in tag, raises without it
- `parse`: extracts doc_id and version from "cc-18011/ed1"
- `parse`: detects pre-release from version suffix
- `parse`: raises on missing slash
- Equality: same tag string → equal
- `to_s` roundtrips: `ReleaseTag.parse(tag.to_s).to_s == tag.to_s`

---

## Acceptance

- [ ] All value objects frozen after construction
- [ ] ISO stage mapping covers stages 20-95
- [ ] Tag suffix logic is pure (no I/O, no state)
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
