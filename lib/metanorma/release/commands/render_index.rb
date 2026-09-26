# frozen_string_literal: true

require "yaml"
require "liquid"
require "json"

module Metanorma
  module Release
    # Renders the document registry index from the aggregated
    # documents.json. Flavor branding comes programmatically from the
    # metanorma-document theme (Theme.load), never from scraping the
    # rendered documents.
    class RenderIndexCommand
      DEFAULT_TEMPLATE = File.expand_path("../templates/index.html.liquid", __dir__)
      DEFAULT_CSS = File.expand_path("../templates/registry.css", __dir__)

      Config = Struct.new(:data, :template, :out, :docs_dir, :manifest,
                          :flavor, :css, keyword_init: true)

      def initialize(config)
        @config = config
      end

      def call
        docs = JSON.parse(File.read(@config.data))["items"]
        manifest = load_manifest
        format_count = docs.flat_map { |d| d["files"] }
                           .map { |f| f["format"] }.uniq.size

        html = Liquid::Template.parse(File.read(template)).render(
          { "documents" => docs,
            "generated" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "organization" => manifest["organization"],
            "site_name" => manifest["name"],
            "format_count" => format_count,
            "theme_css" => theme_css,
            "base_css" => base_css,
            "logo_html" => logo_html },
        )
        FileUtils.mkdir_p(File.dirname(@config.out))
        File.write(@config.out, html)
        @config.out
      end

      private

      # Resolution order for both template and stylesheet: the FLAVOR's
      # theme directory (flavor gems own their registry styling), then
      # the explicit CLI override, then the built-in default.
      def template
        @config.template || theme_template || DEFAULT_TEMPLATE
      end

      def theme_template
        return nil unless flavor_theme

        flavor_theme.resolve_template("index.html.liquid")
      end

      def theme_css_file
        return @config.css if @config.css
        return nil unless flavor_theme

        flavor_theme.resolve_asset("registry.css")
      end

      def flavor_theme
        return nil unless @config.flavor

        theme
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

      # Flavor branding, programmatically from the metanorma-document
      # theme — tokens and logo, no scraping of rendered files.
      def theme
        @theme ||= begin
          require "metanorma/html"
          if @config.flavor
            # Loading the flavor gem runs its programmatic theme
            # registration (register_themes_dir), so Theme.load resolves
            # to the flavor's own copy.
            require "metanorma/#{@config.flavor}"
            Metanorma::Html::Theme.load(@config.flavor.to_sym)
          else
            Metanorma::Html::Theme.new
          end
        end
      end

      def theme_css
        theme.to_css_root
      end

      def base_css
        File.read(theme_css_file || DEFAULT_CSS)
      end

      def logo_html
        theme.logos.each_value do |filename|
          path = theme.resolve_asset(filename.to_s)
          next unless path && File.exist?(path)

          svg = File.read(path)
          return %(<span class="brand-logo">#{svg}</span>)
        end
        nil
      end
    end
  end
end
