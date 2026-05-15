# frozen_string_literal: true

module Metanorma
  module Release
    module Platform
      autoload :GitHub, 'metanorma/release/platform/github'
      autoload :Local, 'metanorma/release/platform/local'
      autoload :Null, 'metanorma/release/platform/null'
    end
  end
end
