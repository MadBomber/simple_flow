require 'minitest/autorun'
require_relative '../lib/simple_flow'

class TestSimpleFlowPipeline < Minitest::Test
  def test_pipeline_with_no_step
    pipeline = SimpleFlow::Pipeline.new
    result = SimpleFlow::Result.new("test")
    final_result = pipeline.call(result)

    assert_equal "test", final_result.value
  end

  def test_pipeline_with_one_step
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue("processed") }
    end

    result = pipeline.call(SimpleFlow::Result.new("initial"))
    assert_equal "processed", result.value
  end

  def test_pipeline_with_multiple_steps
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(1) }
      step ->(result) { result.continue(result.value + 1) }
    end

    result = pipeline.call(SimpleFlow::Result.new(0))
    assert_equal 2, result.value
  end

  def test_pipeline_with_middleware
    middleware = ->(callable) {
      ->(result) {
        modified_result = callable.call(result)
        modified_result.continue(modified_result.value * 2)
      }
    }

    pipeline = SimpleFlow::Pipeline.new do
      use_middleware middleware
      step ->(result) { result.continue(1) }
    end

    result = pipeline.call(SimpleFlow::Result.new(0))
    assert_equal 2, result.value
  end

  def test_pipeline_stops_when_continue_is_false
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.halt }
      step ->(result) { result.continue("should not process") }
    end

    result = pipeline.call(SimpleFlow::Result.new("initial"))
    refute result.continue?, "Pipeline should have stopped"
    assert_equal "initial", result.value, "Value should not have changed"
  end

  def test_pipeline_with_context
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.with_context(:step1, true).continue(result.value) }
      step ->(result) { result.with_context(:step2, true).continue(result.value + 10) }
    end

    result = pipeline.call(SimpleFlow::Result.new(5))
    assert_equal 15, result.value
    assert_equal true, result.context[:step1]
    assert_equal true, result.context[:step2]
  end

  def test_pipeline_with_errors
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.with_error(:validation, "Invalid input").continue(result.value) }
    end

    result = pipeline.call(SimpleFlow::Result.new("data"))
    assert_equal ["Invalid input"], result.errors[:validation]
  end
end
