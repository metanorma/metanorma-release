# frozen_string_literal: true

require "yaml"

module Metanorma
  module Release
    class Config
      def self.from_yaml(yaml_string, org_config: nil)
        data = YAML.safe_load(yaml_string, permitted_classes: [Symbol])
        new(data || {}, org_config: org_config)
      end

      def self.from_file(path, org_config: nil)
        unless File.exist?(path)
          raise ArgumentError,
                "Config file not found: #{path}"
        end

        from_yaml(File.read(path), org_config: org_config)
      end

      def self.defaults(org_config: nil)
        new({}, org_config: org_config)
      end

      def initialize(data, org_config: nil)
        @data = data
        @org_config = org_config
      end

      def org
        @data["org"]
      end

      def channels
        @data.fetch("channels", [])
      end

      def routing
        @data.fetch("routing", {})
      end

      def routing_default
        routing.fetch("default", ["public"])
      end

      def routing_rules
        routing.fetch("rules", [])
      end

      def slug_config
        @data.fetch("slug", {})
      end

      def slug_default_strategy
        slug_config.fetch("default", "edition")
      end

      def slug_strategies
        slug_config.fetch("strategies", {})
      end

      def documents
        @data.fetch("documents", [])
      end

      def defaults
        @data.fetch("defaults", {})
      end

      def default_channels
        list = defaults.fetch("channels", nil)
        return ["public"] unless list

        list
      end

      def resolve_channels(publication)
        manifest_channels = resolve_manifest_channels(publication)
        return manifest_channels if manifest_channels

        rule_channels = resolve_routing_rules(publication)
        return rule_channels if rule_channels

        org_rule_channels = resolve_org_routing_rules(publication)
        return org_rule_channels if org_rule_channels

        local_default = routing_default
        return local_default unless local_default == ["public"] && @org_config

        org_default = @org_config&.routing_default
        return org_default unless org_default.nil? || org_default.empty?

        default_channels
      end

      private

      def resolve_manifest_channels(publication)
        documents.each do |entry|
          next unless entry["source"] && publication.source_path&.end_with?(entry["source"])
          return entry["channels"] if entry["channels"]
        end
        nil
      end

      def resolve_routing_rules(publication)
        routing_rules.each do |rule|
          match = true
          match &&= Array(rule["stage"]).map(&:to_s).include?(publication.stage.to_s) if rule["stage"]
          match &&= Array(rule["doctype"]).map(&:to_s).include?(publication.doctype.to_s) if rule["doctype"]
          return rule["channels"] if match && rule["channels"]
        end
        nil
      end

      def resolve_org_routing_rules(publication)
        return nil unless @org_config

        @org_config.routing_rules.each do |rule|
          match = true
          match &&= Array(rule["stage"]).map(&:to_s).include?(publication.stage.to_s) if rule["stage"]
          match &&= Array(rule["doctype"]).map(&:to_s).include?(publication.doctype.to_s) if rule["doctype"]
          return rule["channels"] if match && rule["channels"]
        end
        nil
      end
    end
  end
end
