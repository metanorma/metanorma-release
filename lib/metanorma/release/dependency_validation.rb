# frozen_string_literal: true

module Metanorma
  module Release
    module DependencyValidation
      private

      def validate_interface!(obj, mod, name)
        return if obj.is_a?(mod) || begin
          obj.class.ancestors.include?(mod)
        rescue StandardError
          false
        end

        raise ArgumentError, "#{name} must include #{mod}, got #{obj.class}"
      end
    end
  end
end
