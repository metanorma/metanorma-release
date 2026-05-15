# 11 — Asset Processor & File Routing

## Summary

Implement the asset processor that extracts zip files from releases and organizes them on disk, plus the file routing strategies (`by-document`, `flat`, `by-format`) that determine the output directory structure.

## Dependencies

- 01-project-scaffold
- 10-document-index (DocumentFile, AggregatedDocument)

## Creates

```
lib/metanorma/release/
├── asset_processor.rb
└── file_routing.rb

spec/aggregation/
├── asset_processor_spec.rb
└── file_routing_spec.rb
spec/fixtures/
└── zips/
    ├── cc-18011-ed1.zip         # Contains: cc-18011-ed1.html, cc-18011-ed1.pdf, cc-18011-ed1.xml, cc-18011-ed1.rxl
    └── multi_file.zip           # Contains multiple documents
```

## Design Principles

### File routing is a strategy pattern
Each routing mode is a standalone object that computes the output path for a given file. The `AssetProcessor` delegates to the routing strategy. New routing modes are added without modifying the processor.

### Canonicalization is a processor concern
Stripping edition suffixes from filenames (`cc-18011-ed1.pdf` → `cc-18011.pdf`) happens during extraction. This is controlled by a flag on the processor, not the routing strategy.

### by-document is the default
Each document gets its own subdirectory. This avoids flat directories with 500+ files and gives clean URL structure.

---

## FileRouting

```ruby
module Metanorma::Release::FileRouting
  # Interface
  def compute_path(file_name, metadata)       # => String (relative path)
end

# by-document: cc-18011-2018/cc-18011-2018.html
class ByDocument
  include FileRouting
  def compute_path(file_name, metadata)       # "{id}/{file_name}"
end

# flat: cc-18011-2018.html
class Flat
  include FileRouting
  def compute_path(file_name, metadata)       # "{file_name}"
end

# by-format: html/cc-18011-2018.html
class ByFormat
  include FileRouting
  def compute_path(file_name, metadata)       # "{ext}/{file_name}"
end

# Factory
def self.from_name(name)                      # "by-document" → ByDocument.new
end
```

`metadata` is a hash with at least `id` (the document identifier string).

### Specs
- `ByDocument`: `"cc-18011-2018.html"` with id `"cc-18011-2018"` → `"cc-18011-2018/cc-18011-2018.html"`
- `Flat`: `"cc-18011-2018.html"` → `"cc-18011-2018.html"`
- `ByFormat`: `"cc-18011-2018.html"` → `"html/cc-18011-2018.html"`
- `ByFormat`: `"cc-18011-2018.pdf"` → `"pdf/cc-18011-2018.pdf"`
- `from_name("by-document")` → ByDocument instance
- `from_name("flat")` → Flat instance
- `from_name("by-format")` → ByFormat instance
- `from_name("unknown")` raises ArgumentError

---

## AssetProcessor

```ruby
class Metanorma::Release::AssetProcessor
  ProcessResult = Struct.new(:files, :channels, keyword_init: true)

  def initialize(output_dir:, routing:, canonicalize: true)
    @output_dir = output_dir
    @routing = routing              # FileRouting implementation
    @canonicalize = canonicalize
  end

  # Extract zip contents and organize on disk
  def process(zip_data, metadata)               # => ProcessResult
    # 1. Extract zip to temp dir
    # 2. For each file in zip:
    #    a. Optionally canonicalize filename (strip edition suffix)
    #    b. Compute output path via routing strategy
    #    c. Copy to output_dir/computed_path
    # 3. Return ProcessResult with list of DocumentFile
  end
end
```

### Canonicalization rules (ported from TS aggregate action):

Strip edition suffixes: `cc-18011-ed1.pdf` → `cc-18011.pdf`, `cc-18011-ed1-wd.pdf` → `cc-18011-wd.pdf`

Pattern: `/-ed\d+(\.\d+)?(-[a-z0-9]+)?\./` → `"."`

### Specs

**Extraction**:
- Extract zip with single document → files in correct locations
- Extract zip with multiple files → all files extracted
- Empty zip → empty result (no error)

**Canonicalization**:
- `canonicalize: true`: `cc-18011-ed1.pdf` → `cc-18011.pdf`
- `canonicalize: true`: `cc-18011-ed1-wd.pdf` → `cc-18011-wd.pdf`
- `canonicalize: false`: filenames preserved as-is
- Multi-part edition: `cc-18011-ed1.1.pdf` → `cc-18011.pdf`

**File routing**:
- `by-document`: files placed in document subdirectory
- `flat`: files placed in output root
- `by-format`: files grouped by extension

**Output**:
- `ProcessResult.files` contains DocumentFile with correct name and path
- Files are actually written to disk at the correct locations
- Existing files are overwritten
- Missing subdirectories are created

**Error handling**:
- Invalid zip data raises clear error
- Permission denied on output dir raises clear error

---

## Acceptance

- [ ] All 3 routing modes produce correct paths
- [ ] Canonicalization strips edition suffixes correctly
- [ ] AssetProcessor extracts and writes files
- [ ] Strategy pattern: new routing modes added without modifying processor
- [ ] No `send`, no `respond_to?`
- [ ] All specs pass
