# frozen_string_literal: true

require_relative "lib/simple_flow/version"

Gem::Specification.new do |spec|
  spec.name = "simple_flow"
  spec.version = SimpleFlow::VERSION
  spec.authors = ["Dewayne VanHoozer"]
  spec.email = ["dvanhoozer@gmail.com"]

  spec.summary = "A lightweight, modular Ruby framework for building composable data processing pipelines"
  spec.description = "SimpleFlow provides a clean and flexible architecture for orchestrating multi-step workflows with middleware support, flow control, parallel execution, and immutable results. Perfect for building data processing pipelines with cross-cutting concerns like logging and instrumentation."
  spec.homepage = "https://github.com/MadBomber/simple_flow"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/MadBomber/simple_flow"
  spec.metadata["changelog_uri"] = "https://github.com/MadBomber/simple_flow/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://github.com/MadBomber/simple_flow/blob/main/README.md"
  spec.metadata["bug_tracker_uri"] = "https://github.com/MadBomber/simple_flow/issues"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir["{lib}/**/*", "LICENSE", "README.md", "CHANGELOG.md"].reject { |f| File.directory?(f) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  # spec.add_dependency "example-gem", "~> 1.0"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
