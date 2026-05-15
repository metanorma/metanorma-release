# 02 — Core Value Objects

## Summary

Implement the foundational value objects shared by both pipelines: `DocumentId`, `ContentHash`, `RepoRef`, `Channel`, `ChannelAudience`.

## Dependencies

- 01-project-scaffold

## Creates

```
lib/metanorma/release/
├── document_id.rb
├── content_hash.rb
├── repo_ref.rb
├── channel.rb
└── channel_audience.rb

spec/domain/
├── document_id_spec.rb
├── content_hash_spec.rb
├── repo_ref_spec.rb
├── channel_spec.rb
└── channel_audience_spec.rb
```

## Design Principles

### Immutability
All value objects are frozen after construction. No setters, no mutation. Equality is value-based (`eql?` + `hash`).

### No `send`, no `respond_to?`
Objects expose their interface through public methods. No introspection needed — if you have a `DocumentId`, you call `.to_s` or `.tag_prefix`. Type contracts are enforced through module inclusion, not runtime probing.

### Factory methods, not constructors
Use `self.from_*` class methods for construction with normalization/validation. The initializer is private or semi-private. This keeps construction logic explicit and prevents creating invalid objects.

---

## DocumentId

```ruby
class Metanorma::Release::DocumentId
  # Construction
  def self.from_raw(raw_identifier)   # "CC 18011" → "cc-18011"
  def self.from_normalized(value)     # "cc-18011" → "cc-18011" (no double-normalization)

  # Accessors
  def to_s                           # "cc-18011"
  def tag_prefix                     # "cc-18011"
  def file_name                      # "cc-18011"

  # Equality (value-based)
  def eql?(other)
  def hash
end
```

Normalization rules (ported from TS `DocumentId.fromRaw`):
1. Lowercase
2. Replace non-alphanumeric runs with single `-`
3. Strip leading/trailing `-`
4. Reject empty result

### Specs
- Normalizes various formats: `"CC 18011"`, `"ISO/IEC 12345-1"`, `"RFC 822"`, `"draft-ietf-quic-34"`
- Rejects empty/whitespace-only identifiers
- Rejects all-non-alphanumeric identifiers (`"---"`, `"///"`)
- Equality: same normalization → equal
- Hash: equal objects → same hash
- `tag_prefix` and `file_name` return the normalized value

---

## ContentHash

```ruby
class Metanorma::Release::ContentHash
  def self.from_hex(hex_string)       # From existing hash
  def self.of_content(data)           # SHA-256 of string/binary data
  def self.of_file(path)              # SHA-256 of file contents
  def self.of_files(paths)            # SHA-256 of concatenated file contents (sorted)

  def to_s                           # Hex string
  def eql?(other)
  def hash
end
```

Uses `Digest::SHA256` from stdlib. `of_files` sorts paths before hashing to ensure deterministic results regardless of file discovery order.

### Specs
- `from_hex` stores and returns the hash
- `of_content` produces consistent hash for same input
- `of_file` reads and hashes a file
- `of_files` sorts paths before hashing (different order → same hash)
- Equality: same hex → equal
- Empty files list → hash of empty string

---

## RepoRef

```ruby
class Metanorma::Release::RepoRef
  def self.new(owner:, repo:)         # Struct-like, frozen
  def owner
  def repo
  def to_s                           # "CalConnect/cc-datetime-explicit"
  def eql?(other)
  def hash
end
```

### Specs
- Construction with owner/repo
- `to_s` format
- Equality: same owner + repo → equal

---

## Channel

```ruby
class Metanorma::Release::Channel
  def self.parse(channel_string)      # "public/standards" → Channel.new(...)
  def self.public(category)           # Channel with Public audience
  def self.members(category)          # Channel with Members audience
  def self.internal(category)         # Channel with Internal audience

  def audience                       # ChannelAudience
  def category                       # "standards"
  def to_s                           # "public/standards"
  def public?                        # audience == Public
  def members?                       # audience == Members
  def matches?(filter_channels)      # True if this channel is in the filter set
  def eql?(other)
  def hash
end
```

Parse rules (ported from TS `Channel.parse`):
- `"public/standards"` → audience=Public, category="standards"
- `"standards"` (no slash) → audience=Public, category="standards"
- `"members/internal-review"` → audience=Members, category="internal-review"

### Specs
- Parse with audience prefix: `"public/standards"`, `"members/drafts"`, `"internal/working-drafts"`
- Parse without prefix: `"standards"` → audience=Public
- Factory methods: `.public("standards")`, `.members("drafts")`, `.internal("working-drafts")`
- `matches?` with array of Channel objects
- `matches?` with array of strings (parse first, then compare)
- Equality: same audience + category → equal
- `to_s` always includes audience prefix

---

## ChannelAudience

```ruby
module Metanorma::Release::ChannelAudience
  PUBLIC = "public"
  MEMBERS = "members"
  INTERNAL = "internal"

  def self.values                    # [PUBLIC, MEMBERS, INTERNAL]
  def self.from_string(raw)          # Parse with validation
end
```

Not an enum (Ruby doesn't have native enums). Module constants with a parse method that raises on unknown values.

### Specs
- `from_string` returns correct constant for known values
- `from_string` raises on unknown value
- `values` returns all three

---

## Acceptance

- [ ] All value objects are frozen after construction
- [ ] All specs pass
- [ ] No `send`, no `respond_to?` in implementation
- [ ] No runtime dependencies beyond stdlib
