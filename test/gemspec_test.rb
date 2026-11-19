# frozen_string_literal: true

require 'minitest/autorun'

class GemspecTest < Minitest::Test
  GEMSPEC = File.expand_path('../simple_flow.gemspec', __dir__)

  def test_declares_former_stdlib_gems_it_requires
    names = Gem::Specification.load(GEMSPEC).runtime_dependencies.map(&:name)

    assert_empty %w[logger tsort] - names
  end
end
