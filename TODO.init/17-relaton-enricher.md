# 17 — Relaton Enricher

## Summary

Optional post-aggregation step that parses RXL files from the aggregate output and generates Relaton bibliography data (`relaton/index.json` + `relaton/index.yaml`). Uses the `relaton-*` gem family for parsing, auto-detected from document flavor.

## Dependencies

- 01-project-scaffold
- 10-document-index (AggregatedDocument, DocumentIndex)
- 11-asset-processor (DocumentFile)

## Creates

```
lib/metanorma/release/
└── relaton_enricher.rb

spec/aggregation/
└── relaton_enricher_spec.rb
spec/fixtures/
└── relaton/
    └── sample.rxl
```

## Design Principles

### Optional dependency
`relaton` and flavor-specific gems (`relaton-calconnect`, `relaton-iso`, etc.) are NOT in the gemspec. The enricher loads them at runtime and skips gracefully if unavailable — same pattern as `octokit` for GitHub adapters.

### Flavor-agnostic
The enricher accepts a `flavor` parameter (e.g., `"calconnect"`, `"iso"`, `"ogc"`) and requires the matching `relaton-{flavor}` gem. The `AggregatedDocument.flavor` field (already in the index) can auto-detect this.

### Runs on aggregate output, not raw files
The enricher receives the `DocumentIndex` and output directory — the same data the aggregation pipeline produced. It finds RXL files via `DocumentIndex#documents` and their `files` arrays.

---

## RelatonEnricher

```ruby
class Metanorma::Release::RelatonEnricher
  EnrichResult = Struct.new(:item_count, :output_dir, keyword_init: true)

  def initialize(flavor: nil, registry_name: "Document Registry")
    @flavor = flavor
    @registry_name = registry_name
  end

  # Generate Relaton bibliography from RXL files in the aggregate output
  def enrich(document_index, output_dir, bib_dir: "relaton")
    # 1. Require relaton flavor gem
    # 2. Find RXL files from document_index.documents
  # 3. Parse each RXL via Relaton::{Flavor}::Item.from_xml
    # 4. Collect items, skip unparseable ones with warning
    # 5. Write relaton/index.json and relaton/index.yaml
    # 6. Return EnrichResult
  rescue LoadError
    warn "  (relaton#{@flavor ? '-' + @flavor : ''} gem not available — bibliography skipped)"
    nil
  end

  private

  def require_flavor
    if @flavor
      require "relaton/#{@flavor}"
    else
      require "relaton"
    end
  end

  def rxl_files(document_index, output_dir)
    document_index.documents.filter_map do |doc|
      rxl = doc.files.find { |f| f.extension == "rxl" }
      next unless rxl
      File.join(output_dir, rxl.path)
    end.select { |p| File.exist?(p) }
  end

  def relaton_class
    # Relaton::Calconnect::Item, Relaton::Iso::Item, etc.
    # Falls back to Relaton::Bib::Item for unknown flavors
  end
end
```

### Output format

```json
{
  "root": {
    "title": "CalConnect Document Registry",
    "items": [
      { /* full Relaton JSON from .to_h */ },
      ...
    ]
  }
}
```

Both `index.json` (pretty-printed) and `index.yaml` are written to `{output_dir}/{bib_dir}/`.

### Specs

**Happy path**:
- Enrich with valid RXL files → produces index.json and index.yaml
- Item count matches RXL file count
- Output is valid JSON parseable by `JSON.parse`

**Flavor handling**:
- Flavor "calconnect" → requires "relaton/calconnect"
- Flavor nil → requires "relaton"
- Missing flavor gem → returns nil with warning (no error)

**Error handling**:
- Malformed RXL → skipped with warning, other files processed
- No RXL files → returns nil with info message
- Empty document index → returns nil

**Auto-detection**:
- If no flavor specified, uses first document's `flavor` field
- Mixed flavors → uses first document's flavor (documented limitation)

---

## Acceptance

- [ ] Produces relaton/index.json and relaton/index.yaml from RXL files
- [ ] Gracefully skips when relaton gem not installed
- [ ] Flavor-agnostic: works with any relaton-* gem
- [ ] Malformed RXL files don't crash the enricher
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
