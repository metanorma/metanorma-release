# frozen_string_literal: true

module Metanorma
  module Release
    class ConfigLocator
      CONFIG_FILES = [".metanorma.yml", ".metanorma.yaml"].freeze
      CONFIG_DIRS = [".metanorma"].freeze

      def self.find(start_dir = Dir.pwd)
        new.find(start_dir)
      end

      def find(start_dir)
        dir = File.expand_path(start_dir)
        loop do
          CONFIG_FILES.each do |name|
            path = File.join(dir, name)
            return ChannelConfig.from_file(path) if File.exist?(path)
          end

          CONFIG_DIRS.each do |name|
            path = File.join(dir, name)
            next unless File.directory?(path)

            channels = File.join(path, "channels.yml")
            return ChannelConfig.from_file(channels) if File.exist?(channels)
          end

          parent = File.dirname(dir)
          return nil if parent == dir

          dir = parent
        end
      end
    end
  end
end
