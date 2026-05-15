# frozen_string_literal: true

require_relative 'lib/metanorma/release'

Gem::Specification.new do |spec|
  spec.name          = 'metanorma-release'
  spec.version       = Metanorma::Release::VERSION
  spec.authors       = ['Ribose Inc.']
  spec.email         = ['open.source@ribose.com']

  spec.summary       = 'Release lifecycle management for Metanorma documents'
  spec.description   = 'Manages the full release lifecycle of Metanorma documents: ' \
                       'discover compiled documents, extract metadata, detect changes, ' \
                       'package as zip, publish to platforms (GitHub Releases, GitLab, ' \
                       'local filesystem), and aggregate published releases into ' \
                       'index.json with a file tree for any site generator.'
  spec.homepage      = 'https://github.com/metanorma/metanorma-release'
  spec.license       = 'BSD-2-Clause'

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__,
                                             err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github
                          Gemfile])
    end
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 3.2'

  spec.metadata['homepage_uri']        = spec.homepage
  spec.metadata['source_code_uri']     = spec.homepage
  spec.metadata['changelog_uri']       = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.add_runtime_dependency 'relaton-bib', '~> 2.1'

  spec.add_development_dependency 'rake', '~> 13.2'
  spec.add_development_dependency 'rspec', '~> 3.13'
end
