# 04 — Document Type Detection & Naming Strategy Registry

## Summary

Implement `DocumentType` (identifier-based detection for 17 SDO flavors) and `NamingStrategy` (5 strategies + Open/Closed registry). This is pure domain logic — no I/O, no platform dependencies.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (DocumentId)
- 03-stage-version-model (ReleaseTag, DocumentVersion)

## Creates

```
lib/metanorma/release/
├── document_type.rb
└── naming_strategy.rb

spec/domain/
├── document_type_spec.rb
└── naming_strategy_spec.rb
```

## Design Principles

### Open/Closed via Registry
New document types are added by registering a new `NamingStrategy` — no changes to existing strategies or the registry. The registry resolves by `DocumentType`, defaulting to `EditionNaming`.

### Detection is identifier-based, not flavor-based
The document type is determined by the identifier prefix (e.g., `"ISO"` → ISO, `"draft-"` → IETF Draft), not by the Metanorma flavor. This is important because flavor is a compile-time concern, while release is a post-compile concern.

### Strategy pattern, not conditionals
Each naming strategy is a standalone object implementing the same interface. No `if type == :iso ... elsif type == :ietf ...` chains.

---

## DocumentType

```ruby
module Metanorma::Release::DocumentType
  # Constants for known types
  STANDARD = "standard"
  IETF_DRAFT = "ietf-draft"
  IETF_RFC = "ietf-rfc"
  ISO = "iso"
  IEC = "iec"
  IEEE = "ieee"
  ITU = "itu"
  BIPM = "bipm"
  IHO = "iho"
  OGC = "ogc"
  OIML = "oiml"
  UN = "un"
  CSA = "csa"
  PDFA = "pdfa"
  MPFA = "mpfa"
  M3AAWG = "m3aawg"
  RIBOSE = "ribose"

  # Detection from identifier string
  def self.from_identifier(raw_id)   # => String (one of the constants)
end
```

Detection rules (ported from TS `DocumentType.fromIdentifier`, order matters):

| Pattern | Type |
|---------|------|
| `/^RFC\s/i` | ietf-rfc |
| `/^draft-/i` | ietf-draft |
| `/^ISO/i` | iso |
| `/^IEC/i` | iec |
| `/^IEEE/i` | ieee |
| `/^ITU-/i` | itu |
| `/^BIPM/i` | bipm |
| `/^[A-Z]-\d/i` | iho |
| `/^\d{2}-\d{2,3}/` | ogc |
| `/^OIML/i` | oiml |
| `/^GE\./i` | un |
| `/^csa-/i` | csa |
| `/^(AN\|BPG\|TN)\s/i` | pdfa |
| `/^SU\//i` | mpfa |
| `/^M3AAWG/i` | m3aawg |
| `/^Ribose/i` | ribose |
| (default) | standard |

### Specs
- Each regex rule matches its intended identifier format
- Priority: first match wins (e.g., `"RFC 822"` → ietf-rfc, not standard)
- Unknown identifiers default to "standard"
- Case-insensitive matching where applicable
- Edge cases: empty string → standard, numeric-only → standard

---

## NamingStrategy

```ruby
module Metanorma::Release::NamingStrategy
  # Interface — all strategies implement these methods
  def compute_tag(id, version)            # => ReleaseTag
  def compute_asset_name(id, version)     # => "cc-18011-ed1.zip"
  def compute_canonical_base(id, version) # => "cc-18011-ed1"
end
```

### 5 Strategies

**EditionNaming** (default, used by CalConnect, ISO, IEC, BIPM, OIML, UN, CSA, M3AAWG, MPFA, PDFA, Ribose):
```
tag: {id}/ed{edition}[-{stage}]
asset: {id}-ed{edition}[-{stage}].zip
canonical: {id}-ed{edition}[-{stage}]
```

**VersionNaming** (IHO, OGC):
```
tag: {id}/v{edition}
asset: {id}-v{edition}.zip
canonical: {id}-v{edition}
```

**InternetDraftNaming** (IETF drafts):
```
tag: id-{name}/{draft-num}        (extracted from "draft-ietf-{name}-{N}")
asset: draft-ietf-{name}-{N}.zip
canonical: draft-ietf-{name}-{N}
fallback tag: {id}/draft
```

**RfcNaming** (IETF RFCs):
```
tag: {id}/ed{edition}
asset: {id}.zip                    (stable — no edition in asset name)
canonical: {id}-ed{edition}
```

**DraftSuffixNaming** (IEEE):
```
tag: {base}/{draft-num}            (extracted from "{id}-d{N}" suffix)
asset: {id}.zip
canonical: {id}
fallback: EditionNaming
```

### NamingRegistry

```ruby
class Metanorma::Release::NamingRegistry
  def initialize(default: EditionNaming.new)
  def register(document_type, strategy)    # Open/Closed: add new types
  def resolve(document_type)               # => NamingStrategy
end

# Factory method for the default registry with all 5 strategies
def self.default_registry
```

Default registrations:
- `ietf-draft` → InternetDraftNaming
- `ietf-rfc` → RfcNaming
- `ieee` → DraftSuffixNaming
- `iho`, `ogc` → VersionNaming
- Everything else → EditionNaming (default)

### Specs

**Per-strategy specs** (5 files or one file with shared examples):

Use a shared example to verify the interface contract:
```ruby
shared_examples "a naming strategy" do
  it { is_expected.to respond_to(:compute_tag) }
  it { is_expected.to respond_to(:compute_asset_name) }
  it { is_expected.to respond_to(:compute_canonical_base) }
end
```

Wait — no `respond_to`. Use direct invocation instead:
```ruby
shared_examples "a naming strategy" do |id:, version:, expected_tag:, expected_asset:, expected_canonical:|
  it "computes tag" do
    expect(strategy.compute_tag(id, version).to_s).to eq(expected_tag)
  end
  it "computes asset name" do
    expect(strategy.compute_asset_name(id, version)).to eq(expected_asset)
  end
  it "computes canonical base" do
    expect(strategy.compute_canonical_base(id, version)).to eq(expected_canonical)
  end
end
```

**EditionNaming**:
- Published: id="cc-18011", ed="1" → tag="cc-18011/ed1", asset="cc-18011-ed1.zip"
- Draft: id="cc-18011", ed="1", stage=working-draft → tag="cc-18011/ed1-wd", asset="cc-18011-ed1-wd.zip"

**VersionNaming**:
- id="s-100", ed="5" → tag="s-100/v5", asset="s-100-v5.zip"

**InternetDraftNaming**:
- id="draft-ietf-quic-34" → tag="id-quic/34", asset="draft-ietf-quic-34.zip"
- id="cc-18011" (no match) → fallback: tag="cc-18011/draft"

**RfcNaming**:
- id="rfc-822", ed="1" → tag="rfc-822/ed1", asset="rfc-822.zip" (no edition in asset)

**DraftSuffixNaming**:
- id="ieee-draft-std-987-6-2020-d3" → tag="ieee-draft-std-987-6-2020/3", asset="ieee-draft-std-987-6-2020-d3.zip"
- id="ieee-std-123" (no -dN suffix) → fallback: EditionNaming

**NamingRegistry**:
- Default resolves to EditionNaming for unknown types
- Registered types resolve to their strategies
- Can register custom types (Open/Closed)
- `default_registry` has all 5 strategies pre-registered

---

## Acceptance

- [ ] All 17 document types detected correctly
- [ ] All 5 naming strategies produce correct output for their formats
- [ ] Registry resolves correctly for registered and unregistered types
- [ ] No conditionals in registry dispatch (strategy pattern)
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
