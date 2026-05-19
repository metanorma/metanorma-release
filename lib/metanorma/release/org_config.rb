# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class OrgConfig
      Ref = Struct.new(:owner, :repo, :name, keyword_init: true)

      def self.parse_ref(org_string)
        parts = org_string.to_s.split("#", 2)
        slug = parts[0].to_s.strip
        segments = slug.split("/", 2)
        raise ArgumentError, "Invalid org reference: #{org_string}" unless segments.length == 2

        Ref.new(owner: segments[0], repo: segments[1], name: parts[1]&.strip)
      end

      def self.default_config_name
        "channels"
      end

      def self.remote_path(ref)
        name = ref.name || default_config_name
        ".metanorma/#{name}.yml"
      end

      def self.from_yaml(yaml_string)
        data = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        new(data || {})
      end

      def self.from_file(path)
        raise ArgumentError, "Org config file not found: #{path}" unless File.exist?(path)

        from_yaml(File.read(path))
      end

      def self.defaults
        new({})
      end

      def initialize(data)
        @data = data
      end

      def channels
        @data.fetch("channels", [])
      end

      def routing_default
        dig_defaults_routing("default") || []
      end

      def routing_rules
        dig_defaults_routing("rules") || []
      end

      def valid_channel?(name)
        return true if channels.empty?

        ch = Channel.new(name)
        channels.any? do |valid|
          valid_ch = Channel.new(valid)
          ch.eql?(valid_ch) || ch.name.start_with?("#{valid_ch.name}/") || valid_ch.name.start_with?("#{ch.name}/")
        end
      end

      def display_categories
        @data.fetch("display_categories", [])
      end

      def display_category_for(doctype)
        return nil if doctype.nil? || doctype.empty?

        display_categories.each do |cat|
          doctypes = cat["doctypes"] || []
          return { "name" => cat["name"], "slug" => cat["slug"] } if doctypes.include?(doctype)
        end
        nil
      end

      private

      def dig_defaults_routing(key)
        @data.dig("defaults", "routing", key)
      end
    end
  end
end
