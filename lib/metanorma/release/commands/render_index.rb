# frozen_string_literal: true

require "yaml"
require "liquid"
require "json"

module Metanorma
  module Release
    class RenderIndexCommand
      DEFAULT_TEMPLATE = File.expand_path("../templates/index.html.liquid", __dir__)

      Config = Struct.new(:data, :template, :out, :assets, :docs_dir,
                          :manifest, keyword_init: true)

      def initialize(config)
        @config = config
      end

      def call
        docs = JSON.parse(File.read(@config.data))["items"]
        manifest = load_manifest
        html = Liquid::Template.parse(File.read(template)).render(
          { "documents" => docs,
            "generated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "organization" => manifest["organization"],
            "site_name" => manifest["name"],
            "format_count" => docs.flat_map { |d| d["files"] }
                                  .map { |f| f["format"] }.uniq.size,
            "logo_html" => extract_logo },
        )
        FileUtils.mkdir_p(File.dirname(@config.out))
        File.write(@config.out, html)
        copy_assets
        @config.out
      end

      private

      def template
        @config.template || DEFAULT_TEMPLATE
      end

      # Site identity comes from the metanorma manifest when present.
      def load_manifest
        path = @config.manifest
        return {} unless path && File.exist?(path)

        collection = YAML.safe_load_file(path).dig("metanorma", "collection") || {}
        { "organization" => collection["organization"],
          "name" => collection["name"] }
      rescue StandardError
        {}
      end

      # Brand continuity: reuse the header logo exactly as the published
      # documents render it (metanorma-document theme).
      def extract_logo
        return nil unless @config.docs_dir

        Dir.glob(File.join(@config.docs_dir, "*.mnd.html")).sort.each do |f|
          body = File.read(f)
          if (m = body.match(%r{<span class="brand-logo[^"]*"[^>]*>\s*(<svg.*?</svg>)}m))
            return m[1]
          end
        end
        nil
      end

      def copy_assets
        return unless @config.assets

        assets_dst = File.join(File.dirname(@config.out), "assets")
        FileUtils.rm_rf(assets_dst)
        FileUtils.cp_r(@config.assets, assets_dst)
      end
    end
  end
end
