# frozen_string_literal: true

require 'digest'

module Metanorma
  module Release
    class ContentHash
      def self.from_hex(hex_string)
        new(hex_string.to_s)
      end

      def self.of_content(data)
        new(Digest::SHA256.hexdigest(data))
      end

      def self.of_file(path)
        new(Digest::SHA256.file(path).hexdigest)
      end

      def self.of_files(paths)
        sorted = paths.sort
        digest = Digest::SHA256.new
        sorted.each { |p| digest << File.binread(p) }
        new(digest.hexdigest)
      end

      def self.of_directory(directory, base: nil)
        pattern = base ? File.join(directory, "#{base}.*") : File.join(directory, '**', '*')
        files = Dir.glob(pattern).reject { |f| File.directory?(f) || f.end_with?('.zip') }
        of_files(files)
      end

      def initialize(hex)
        @hex = hex
        freeze
      end

      def to_s
        @hex
      end

      def eql?(other)
        other.is_a?(self.class) && @hex == other.to_s
      end

      def hash
        @hex.hash
      end
    end
  end
end
