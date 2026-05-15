# 06 — Metadata Extraction

## Summary

Implement `ReleaseMetadata` (JSON serialization/deserialization for the `<!-- mn-release-metadata -->` format) and `RxlExtractor` (metadata extraction from Relaton XML files). These bridge the compile output and the release pipeline.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (Channel)
- 03-stage-version-model (DocumentStage, DocumentVersion)

## Creates

```
lib/metanorma/release/
├── release_metadata.rb
├── rxl_extractor.rb
└── document_metadata.rb

spec/release/
├── release_metadata_spec.rb
├── rxl_extractor_spec.rb
└── fixtures/
    ├── sample.rxl
    ├── multi_format.rxl
    └── invalid.rxl
```

## Design Principles

### ReleaseMetadata is a serialization format, not domain logic
It converts between `DocumentMetadata` (domain) and JSON (wire format for release bodies). The format is versioned (`version: 1`) for forward compatibility.

### RxlExtractor is the default extractor
Relaton XML (`.rxl`) is the universal metadata format produced by Metanorma compilation. The extractor discovers RXL files in an output directory and parses them. This is the `IDocumentExtractor` implementation for the release pipeline.

### Graceful degradation
RXL parsing failure produces a warning, not an exception. A document with a malformed RXL can still be released with reduced metadata (tag-derived ID, no title).

---

## ReleaseMetadata

```ruby
class Metanorma::Release::ReleaseMetadata
  SCHEMA_VERSION = 1

  # Construction
  def self.from_document(metadata, channels:)  # From DocumentMetadata + channels
  def self.from_json(json_string)               # Parse from JSON
  def self.from_release_body(body)              # Parse from release body HTML comment

  # Serialization
  def to_json                                    # JSON string
  def to_release_body                            # Embed in HTML comment: <!-- mn-release-metadata\n{...}\n-->
  def to_h                                      # Hash representation

  # Accessors
  def id                                        # String
  def title                                     # String
  def edition                                   # String
  def stage                                     # String
  def doctype                                   # String
  def revdate                                   # String?
  def formats                                   # [String]
  def channels                                  # [String]
  def flavor                                    # String?
  def source_path                               # String
end
```

### HTML comment format (ported from TS `parseReleaseMetadata`):

```
content-hash:{hex}
<!-- mn-release-metadata
{"version":1,"id":"cc-18011","title":"...","edition":"1","stage":"published","doctype":"standard","revdate":null,"formats":["html","pdf","xml","rxl"],"channels":["public/standards"],"flavor":"cc","sourcePath":"sources/cc-18011.adoc"}
-->
```

`content-hash` is a separate line above the metadata comment, for quick extraction without JSON parsing.

### Specs
- `from_document`: converts DocumentMetadata + channels to ReleaseMetadata
- `from_json`: parses valid JSON
- `from_json`: raises on missing required fields
- `from_release_body`: extracts metadata from HTML comment
- `from_release_body`: returns nil when no metadata comment found
- `from_release_body`: returns nil when JSON parse fails
- `to_release_body`: produces valid HTML comment with content-hash
- Round-trip: `from_release_body(body).to_release_body` preserves data
- `from_release_body` with content-hash line extracts hash separately

---

## DocumentMetadata

```ruby
class Metanorma::Release::DocumentMetadata
  # Construction
  def self.new(id:, title:, version:, doctype:, document_type:,
               flavor:, revdate:, source_path:, output_dir:, formats:, file_base_name:)

  # Accessors
  def id                    # DocumentId
  def title                 # String
  def version               # DocumentVersion
  def doctype               # String (semantic: "standard", "report", etc.)
  def document_type         # String (from DocumentType constants: "iso", "ietf-rfc", etc.)
  def flavor                # String? (Metanorma flavor: "cc", "iso", "ogc", etc.)
  def revdate               # String? (revision date)
  def source_path           # String (relative path to source file)
  def output_dir            # String (directory containing compiled artifacts)
  def formats               # [String] (["html", "pdf", "xml", "rxl"])
  def file_base_name        # String (filename prefix for artifacts)
end
```

This is the domain entity extracted from a compiled document. It carries both metadata (id, title, stage) and compilation context (output_dir, formats, file_base_name).

---

## RxlExtractor

```ruby
class Metanorma::Release::RxlExtractor
  def initialize(fallback_flavor: nil)    # Flavor to use when RXL doesn't specify

  # Discover all documents in an output directory
  def discover(output_dir)                # => [DocumentMetadata]

  # Extract metadata from a single RXL file
  def extract(rxl_path)                   # => DocumentMetadata
end
```

### Discovery algorithm:
1. Glob `**/*.rxl` in output_dir
2. For each RXL: parse XML → extract id, title, edition, stage, doctype, revdate
3. Determine `output_dir` as the RXL's parent directory
4. Determine `formats` by scanning sibling files with same base name
5. Detect `document_type` via `DocumentType.from_identifier(id)`
6. Return array of `DocumentMetadata`

### RXL parsing:
Relaton XML structure (simplified):
```xml
<bibdata type="standard">
  <docidentifier>CC 18011:2018</docidentifier>
  <title>...</title>
  <edition>1</edition>
  <status><stage>60</stage></status>
  <date type="published"><on>2018-06-01</on></date>
  <ext>
    <doctype>standard</doctype>
  </ext>
</bibdata>
```

Uses `Nokogiri::XML` (stdlib `REXML` is too slow). Falls back to tag-derived ID when XML is malformed.

### Specs
- Discover finds all RXL files in nested directories
- Extract parses valid RXL: id, title, edition, stage, doctype
- Extract with ISO stage 60 → `DocumentStage.published`
- Extract detects formats from sibling files
- Extract with malformed RXL: logs warning, returns metadata with reduced info
- Extract with missing RXL: raises FileNotFoundError
- `document_type` detected from identifier
- Empty output dir → empty array
- Multiple RXL files → multiple DocumentMetadata
- Formats include rxl when RXL file exists alongside other artifacts

---

## Acceptance

- [ ] ReleaseMetadata round-trips through JSON and HTML comment format
- [ ] RxlExtractor discovers and parses RXL files
- [ ] Graceful handling of malformed RXL
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
