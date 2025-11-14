# frozen_string_literal: true

require 'test_helper'

class TestSimpleFlowPipeline < Minitest::Test
  def test_pipeline_with_no_step
    pipeline = SimpleFlow::Pipeline.new
    result = SimpleFlow::Result.new(nil)
    final_result = pipeline.call(result)
    assert_nil final_result.value
    assert final_result.continue?
  end

  def test_pipeline_with_one_step
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue("processed") }
    end
    result = pipeline.call(SimpleFlow::Result.new(nil))
    assert_equal "processed", result.value
  end

  def test_pipeline_with_multiple_steps
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(1) }
      step ->(result) { result.continue(result.value + 1) }
    end
    result = pipeline.call(SimpleFlow::Result.new(nil))
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
    result = pipeline.call(SimpleFlow::Result.new(nil))
    assert_equal 2, result.value
  end

  def test_pipeline_stops_when_continue_is_false
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.halt }
      step ->(result) { result.continue("should not process") }
    end
    result = pipeline.call(SimpleFlow::Result.new(nil))
    assert_nil result.value, "Pipeline did not stop as expected"
    refute result.continue?, "Result should be halted"
  end

  def test_to_dot_with_dependency_graph
    pipeline = SimpleFlow::Pipeline.new do
      step :step1, ->(result) { result.continue(result.value) }
      step :step2, ->(result) { result.continue(result.value) }, depends_on: [:step1]
    end

    dot = pipeline.to_dot(title: 'Test Pipeline')

    assert_includes dot, 'digraph "Test Pipeline"'
    assert_includes dot, 'step1'
    assert_includes dot, 'step2'
    assert_includes dot, 'step1 -> step2'
  end

  def test_to_dot_raises_error_without_dependency_graph
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value) }
    end

    error = assert_raises(ArgumentError) do
      pipeline.to_dot
    end

    assert_includes error.message, "Cannot generate DOT"
  end
end
