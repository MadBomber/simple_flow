# frozen_string_literal: true

require "test_helper"

class TestSimpleFlow < Minitest::Test
  def test_that_it_has_a_version_number
    refute_nil ::SimpleFlow::VERSION
  end

  def test_simple_pipeline_execution
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value.strip.downcase) }
      step ->(result) { result.continue("Hello, #{result.value}!") }
    end

    result = pipeline.call(SimpleFlow::Result.new("  WORLD  "))

    assert_equal "Hello, world!", result.value
    assert result.continue?
  end

  def test_pipeline_with_halt
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) {
        result.value < 18 ?
          result.halt.with_error(:validation, "Must be 18 or older") :
          result.continue(result.value)
      }
      step ->(result) { result.continue("Eligible at age #{result.value}") }
    end

    result = pipeline.call(SimpleFlow::Result.new(15))

    refute result.continue?
    assert_equal 15, result.value
    assert_includes result.errors[:validation], "Must be 18 or older"
  end
end
