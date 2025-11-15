# frozen_string_literal: true

require "test_helper"

class TestSimpleFlow < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::SimpleFlow::VERSION
  end

  def test_simple_pipeline_flow
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value.upcase) }
      step ->(result) { result.continue("Hello, #{result.value}!") }
    end

    result = pipeline.call(SimpleFlow::Result.new("world"))
    assert_equal "Hello, WORLD!", result.value
  end
end
