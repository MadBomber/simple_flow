# frozen_string_literal: true

require_relative "lib/simple_flow/version"

Gem::Specification.new do |spec|
  spec.name = "simple_flow"
  spec.version = SimpleFlow::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "A lightweight, modular Ruby framework for building composable data processing pipelines"
  spec.description = "SimpleFlow provides a clean and flexible architecture for orchestrating multi-step workflows with middleware support, flow control, and immutable results. Perfect for building data processing pipelines with cross-cutting concerns like logging and instrumentation."
  spec.homepage = "https://github.com/MadBomber/simple_flow"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MadBomber/simple_flow"
  spec.metadata["changelog_uri"] = "https://github.com/MadBomber/simple_flow/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/MadBomber/simple_flow/blob/main/README.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/MadBomber/simple_flow/issues"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ Gemfile .gitignore test/])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Optional dependencies for concurrent execution support
  spec.add_dependency "async", "~> 2.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
