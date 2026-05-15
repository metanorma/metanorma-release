# 16 — Integration Specs

## Summary

End-to-end specs that exercise the full pipeline from compilation output to deployed index. These validate that all components compose correctly and that the data flows through the system without loss.

## Dependencies

- 01 through 15 (all previous tasks)

## Creates

```
spec/integration/
├── local_round_trip_spec.rb         # package → aggregate → index, no network
├── release_publish_spec.rb          # publish with mock platform → aggregate → index
├── delta_dedup_spec.rb              # aggregate twice with delta → second run is fast
├── file_routing_spec.rb             # by-document, flat, by-format output structures
├── channel_filtering_spec.rb        # aggregate with channel filter → correct subset
├── verification_spec.rb             # min-documents check, empty results
└── shared_contexts.rb               # "with_compiled_documents", "with_released_documents"
spec/fixtures/
└── integration/
    ├── compiled/                    # Simulated Metanorma compilation output
    │   ├── cc-18011/
    │   │   ├── cc-18011.rxl
    │   │   ├── cc-18011.html
    │   │   ├── cc-18011.pdf
    │   │   └── cc-18011.xml
    │   └── cc-19060/
    │       └── ...
    ├── released/                    # Simulated release packages (zip + metadata)
    │   ├── cc-18011-ed1.zip
    │   ├── cc-18011-ed1.meta.json
    │   ├── cc-19060-ed1.zip
    │   └── cc-19060-ed1.meta.json
    └── manifests/
        └── sample.release.yml
```

## Design Principles

### No network calls
All integration specs use local adapters and file fixtures. No GitHub API, no HTTP. This makes specs fast, deterministic, and runnable offline.

### Test the full data flow
Each spec exercises the entire pipeline, not individual components. The goal is to verify that:
1. Metadata survives the round-trip (RXL → package → metadata → release body → parse → AggregatedDocument)
2. Files end up in the correct locations
3. The index JSON is valid and complete
4. Delta state works across multiple runs

### Test failure modes
Integration specs also test what happens when things go wrong: empty input, missing metadata, invalid zips, permission errors.

---

## Spec: Local Round-Trip

```ruby
describe "Local round-trip: package → aggregate → index" do
  it "produces a valid index from locally packaged documents" do
    # 1. Package compiled documents
    Dir.mktmpdir do |package_dir|
      result = Metanorma::Release::ReleasePipeline.new(
        extractor: RxExtractor.new,
        filters: [],
        change_detector: AlwaysChanged.new,
        packager: ZipPackager.new,
        publisher: LocalPublisher.new(output_dir: package_dir),
        naming_registry: NamingRegistry.default
      ).run(config)

      expect(result.released.length).to be > 0

      # 2. Aggregate from local packages
      agg_result = AggregationPipeline.new(
        discoverer: DirectoryDiscoverer.new(base_path: package_dir),
        fetcher: LocalFetcher.new(base_path: package_dir),
        manifest_reader: NullManifestReader.new,
        channel_filter: ChannelFilter.new([]),
        stage_filter: StageFilter.new([]),
        asset_processor: AssetProcessor.new(output_dir: output_dir, routing: ByDocument.new),
        delta_state: NullDeltaState.new
      ).run(agg_config, output_dir)

      # 3. Verify index
      index = agg_result.documents
      expect(index.length).to eq(result.released.length)
      expect(index.first.id).to match(/cc-\d+/)
      expect(index.first.files.length).to be > 0

      # 4. Verify files on disk
      index.first.files.each do |file|
        expect(File.exist?(File.join(output_dir, file.path))).to be true
      end

      # 5. Verify index JSON is valid
      index_obj = DocumentIndex.from_documents(agg_result.documents, parameters: params)
      json = index_obj.to_json
      parsed = DocumentIndex.from_json(json)
      expect(parsed.document_count).to eq(agg_result.documents.length)
    end
  end
end
```

---

## Spec: Release + Publish + Aggregate

```ruby
describe "Release → Publish → Aggregate" do
  it "round-trips metadata through publish and aggregate" do
    # 1. Release with mock publisher
    released_bodies = {}
    mock_publisher = MockPublisher.new(released_bodies)

    result = ReleasePipeline.new(deps_with(publisher: mock_publisher)).run(config)

    # 2. Verify metadata in release body
    result.released_artifacts.each do |artifact|
      body = released_bodies[artifact.tag]
      metadata = ReleaseMetadata.from_release_body(body)
      expect(metadata).not_to be_nil
      expect(metadata.id).to eq(artifact.id)
    end

    # 3. Aggregate from mock releases
    mock_fetcher = MockFetcher.from_bodies(released_bodies)
    agg_result = AggregationPipeline.new(deps_with(fetcher: mock_fetcher)).run(config, output_dir)

    # 4. Verify metadata preserved through round-trip
    agg_result.documents.each do |doc|
      expect(doc.title).not_to be_empty
      expect(doc.stage).not_to be_empty
    end
  end
end
```

---

## Spec: Delta Dedup

```ruby
describe "Delta dedup across runs" do
  it "skips unchanged releases on second run" do
    cache_dir = Dir.mktmpdir
    cache = FileCacheStore.new(cache_dir)
    delta = DeltaState.new(cache, output_dir)

    # Run 1: all releases are new
    result1 = run_aggregation_with(delta_state: delta)
    expect(result1.documents.length).to be > 0

    # Run 2: all releases are unchanged (same content hash)
    delta2 = DeltaState.new(cache, output_dir)
    result2 = run_aggregation_with(delta_state: delta2)
    expect(result2.documents.length).to eq(result1.documents.length)
    # Files not re-extracted (verified by checking no new writes)
  end
end
```

---

## Spec: File Routing

```ruby
describe "File routing modes" do
  ["by-document", "flat", "by-format"].each do |mode|
    it "produces correct directory structure for #{mode}" do
      routing = FileRouting.from_name(mode)
      result = run_aggregation_with(routing: routing)

      result.documents.each do |doc|
        doc.files.each do |file|
          path = File.join(output_dir, file.path)
          expect(File.exist?(path)).to be true

          case mode
          when "by-document"
            expect(file.path).to start_with("#{doc.id}/")
          when "flat"
            expect(file.path).not_to include("/")
          when "by-format"
            ext = File.extname(file.name).delete_prefix(".")
            expect(file.path).to start_with("#{ext}/")
          end
        end
      end
    end
  end
end
```

---

## Spec: Channel Filtering

```ruby
describe "Channel filtering" do
  it "only includes documents matching the channel filter" do
    result = run_aggregation_with(channels: ["public/standards"])
    result.documents.each do |doc|
      has_standards = doc.channels.any? { |c| c.include?("standards") }
      expect(has_standards).to be true
    end
  end

  it "includes all documents when no filter specified" do
    result = run_aggregation_with(channels: [])
    expect(result.documents.length).to be > 0
  end
end
```

---

## Spec: Verification

```ruby
describe "Verification" do
  it "succeeds when document count meets minimum" do
    result = run_aggregation_with(min_documents: 1)
    expect(result.documents.length).to be >= 1
  end

  it "fails when document count is below minimum" do
    expect {
      run_aggregation_with(min_documents: 999, source: empty_dir)
    }.to raise_error(/minimum.*documents/i)
  end

  it "handles empty source gracefully" do
    result = run_aggregation_with(source: empty_dir)
    expect(result.documents).to be_empty
    expect(result.repo_count).to eq(0)
  end
end
```

---

## Shared Contexts

```ruby
RSpec.shared_context "with compiled documents" do
  let(:compiled_dir) { File.join(__dir__, "../fixtures/integration/compiled") }
  let(:output_dir) { Dir.mktmpdir }
end

RSpec.shared_context "with released documents" do
  let(:released_dir) { File.join(__dir__, "../fixtures/integration/released") }
  let(:output_dir) { Dir.mktmpdir }
end
```

---

## Acceptance

- [ ] Local round-trip spec passes (no network, no external deps)
- [ ] Metadata survives full round-trip without data loss
- [ ] Delta dedup prevents unnecessary re-extraction
- [ ] All 3 file routing modes produce correct directory structures
- [ ] Channel filtering correctly subsets documents
- [ ] Verification gate works for min-documents check
- [ ] All specs pass offline with no network
