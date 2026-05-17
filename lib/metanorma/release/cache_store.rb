# frozen_string_literal: true

require "json"

module Metanorma
  module Release
    module CacheStore
      def get(key)
        raise NotImplementedError, "#{self.class} must implement #get"
      end

      def set(key, value)
        raise NotImplementedError, "#{self.class} must implement #set"
      end

      def delete(key)
        raise NotImplementedError, "#{self.class} must implement #delete"
      end

      def clear
        raise NotImplementedError, "#{self.class} must implement #clear"
      end

      def keys
        raise NotImplementedError, "#{self.class} must implement #keys"
      end
    end

    class FileCacheStore
      include CacheStore

      def initialize(directory)
        @directory = directory
      end

      def get(key)
        path = file_path(key)
        return nil unless File.exist?(path)

        File.read(path)
      end

      def set(key, value)
        FileUtils.mkdir_p(@directory)
        File.write(file_path(key), value)
      end

      def delete(key)
        path = file_path(key)
        FileUtils.rm_f(path)
      end

      def clear
        return unless Dir.exist?(@directory)

        Dir.glob(File.join(@directory, "*")).each do |f|
          File.delete(f) if File.file?(f)
        end
      end

      def keys
        return [] unless Dir.exist?(@directory)

        Dir.glob(File.join(@directory, "*")).select { |f| File.file?(f) }
          .map { |f| File.basename(f) }
      end

      private

      def file_path(key)
        sanitized = key.gsub(/[^a-zA-Z0-9._-]/, "_")
        File.join(@directory, sanitized)
      end
    end

    class NullCacheStore
      include CacheStore

      def get(_key) = nil
      def set(_key, _value) = nil
      def delete(_key) = nil
      def clear = nil
      def keys = []
    end
  end
end
