# 10 — Document Index

## Summary

Implement `AggregatedDocument`, `DocumentFile`, `DocumentSource`, and `DocumentIndex` — the data model for the aggregate output. `DocumentIndex` is the versioned JSON schema that serves as the single data contract between aggregation and any consumer.

## Dependencies

- 01-project-scaffold
- 02-core-value-objects (Channel, RepoRef)

## Creates

```
lib/metanorma/release/
├── aggregated_document.rb
└── document_index.rb

spec/aggregation/
└── document_index_spec.rb
spec/fixtures/
└── index/
    ├── valid_v1.json
    ├── minimal_v1.json
    ├── missing_version.json
    └── empty_documents.json
```

## Design Principles

### Index is the data contract
`DocumentIndex` is the schema. It validates input, provides structured access, and serializes to JSON. Any consumer (Jekyll, Hugo, Vite, shell script) reads this format. No consumer-specific transformation in the gem.

### Schema versioning
`version: 1` is the current schema. Future changes increment the version. `from_json` validates the version and rejects unknown versions. This enables forward-compatible consumers.

### AggregatedDocument is a data structure, not domain logic
It carries the data from aggregation but has no behavior beyond serialization. It's a frozen struct.

---

## DocumentFile

```ruby
Metanorma::Release::DocumentFile = Struct.new(:name, :path, keyword_init: true) do
  def extension                      # ".html" → "html"
  end
end
```

---

## DocumentSource

```ruby
Metanorma::Release::DocumentSource = Struct.new(
  :owner, :repo, :tag, :release_url, :release_date,
  keyword_init: true
) do
  def repo_key                       # "CalConnect/cc-datetime-explicit"
  end
end
```

---

## AggregatedDocument

```ruby
class Metanorma::Release::AggregatedDocument
  def self.from_h(hash)              # Construct from parsed JSON
  def to_h                           # Hash suitable for JSON serialization

  def id                             # String
  def title                          # String
  def edition                        # String
  def stage                          # String ("published", "working-draft", etc.)
  def doctype                        # String (may be empty — derived from channels)
  def channels                       # [String] (["public/standards", "public/reports"])
  def formats                        # [String] (["html", "pdf", "xml", "rxl"])
  def flavor                         # String?
  def content_hash                   # String?
  def source                         # DocumentSource
  def files                          # [DocumentFile]
end
```

### Specs
- `from_h` parses all fields from a hash
- `to_h` produces a hash that round-trips through `from_h`
- Missing optional fields get defaults: doctype→"", content_hash→nil, flavor→nil
- `files` is an array of DocumentFile structs
- `source` is a DocumentSource struct

---

## DocumentIndex

```ruby
class Metanorma::Release::DocumentIndex
  SCHEMA_VERSION = 1

  # Construction
  def self.from_json(json_string)           # Parse + validate
  def self.from_documents(documents,        # Build from AggregatedDocument array
                          parameters:)

  # Accessors
  def documents                             # [AggregatedDocument]
  def parameters                            # { organizations, channels, topic, repo_count }
  def summary                               # { repo_count, document_count, channels_found }
  def channels                              # [String] (deduplicated, sorted)

  # Serialization
  def to_json                               # JSON string
  def to_h                                  # Hash

  # Validation
  def document_count                        # Integer
  def empty?                                # document_count == 0

  # Write to file
  def write(path)                           # Write JSON to file
end

# Struct for parameters
Metanorma::Release::IndexParameters = Struct.new(
  :organizations, :channels, :topic, :repo_count,
  keyword_init: true
)

# Struct for summary
Metanorma::Release::IndexSummary = Struct.new(
  :repo_count, :document_count, :channels_found,
  keyword_init: true
)
```

### JSON format (schema v1):

```json
{
  "version": 1,
  "generatedAt": "2026-05-14T10:30:00Z",
  "parameters": {
    "organizations": ["CalConnect"],
    "channels": [],
    "topic": "metanorma-release",
    "repoCount": 51
  },
  "summary": {
    "repoCount": 51,
    "documentCount": 189,
    "channelsFound": ["public/admin", "public/advisories", "public/standards"]
  },
  "documents": [
    {
      "id": "cc-18011-2018",
      "title": "Date and time — Explicit representation",
      "edition": "1",
      "stage": "published",
      "doctype": "",
      "channels": ["public/standards"],
      "formats": ["html", "pdf", "xml", "rxl"],
      "flavor": "cc",
      "contentHash": "185bd72f...",
      "source": {
        "owner": "CalConnect",
        "repo": "cc-datetime-explicit",
        "tag": "cc-18011-2018/ed1",
        "releaseUrl": "https://...",
        "releaseDate": "2026-05-13T12:21:32Z"
      },
      "files": [
        { "name": "cc-18011-2018.html", "path": "cc-18011-2018/cc-18011-2018.html" },
        { "name": "cc-18011-2018.pdf",  "path": "cc-18011-2018/cc-18011-2018.pdf" }
      ]
    }
  ]
}
```

### Validation in `from_json`:
- `version` must equal `SCHEMA_VERSION` (currently 1)
- `documents` must be an array
- Each document must have `id`, `title` (other fields get defaults)
- Raises `SchemaError` with descriptive message on validation failure

### `from_documents`:
- Takes an array of `AggregatedDocument` and `IndexParameters`
- Auto-computes `summary` (document count, unique channels)
- Sets `generatedAt` to current time
- Auto-computes `channels_found` from all documents' channels

### Specs

**Parsing**:
- `from_json` with valid v1 JSON → DocumentIndex
- `from_json` with missing version → raises SchemaError
- `from_json` with wrong version → raises SchemaError
- `from_json` with missing documents key → raises SchemaError
- `from_json` with empty documents array → valid but empty

**Construction**:
- `from_documents` creates valid index
- `summary.document_count` matches array length
- `summary.channels_found` is deduplicated and sorted
- `parameters` preserved from input

**Serialization**:
- `to_json` produces valid JSON parseable by `from_json`
- `to_h` produces hash with all fields
- `write` creates file on disk

**Accessors**:
- `channels` returns unique sorted channels from all documents
- `document_count` matches array length
- `empty?` true when no documents

---

## Acceptance

- [ ] Schema v1 validates correctly
- [ ] Round-trip: `from_json(json).to_json` preserves data
- [ ] `from_documents` auto-computes summary
- [ ] Clear error messages on schema validation failure
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
