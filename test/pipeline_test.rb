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

  # Issue #61: a value that isn't middleware fails where it is declared
  def test_use_middleware_rejects_a_value_that_is_not_middleware
    [:logging, ->(r) { r }.method(:call)].each do |bad|
      error = assert_raises(ArgumentError) do
        SimpleFlow::Pipeline.new { use_middleware bad }
      end
      assert_includes error.message, bad.inspect
    end
  end

  # Issue #58: the error names the step and what it received
  def test_step_validation_error_names_the_step_and_what_it_got
    cases = {
      -> { SimpleFlow::Pipeline.new { step :fetch, 42 } } => 'Step :fetch must respond to #call (got Integer)',
      -> { SimpleFlow::Pipeline.new { step 42 } } => 'Step must respond to #call (got Integer)',
      -> { SimpleFlow::Pipeline.new { step 'writer', ->(r) { r } } } =>
        'Step must respond to #call (got String); step names must be Symbols',
      -> { SimpleFlow::Pipeline.new { parallel { step :fetch } } } => 'Step :fetch must respond to #call (got NilClass)'
    }

    cases.each do |build, message|
      error = assert_raises(ArgumentError) { build.call }
      assert_equal message, error.message
    end
  end

  # Issue #69: a step that would silently drop a callable raises instead
  def test_step_rejects_an_extra_callable_or_block
    a = ->(r) { r.continue(1) }
    b = ->(r) { r.continue(2) }
    cases = {
      -> { SimpleFlow::Pipeline.new { step a, b } } => /second callable/,
      -> { SimpleFlow::Pipeline.new { step(a) { |r| r } } } => /both a callable and a block/,
      -> { SimpleFlow::Pipeline.new { step(:x, a) { |r| r } } } => /Step :x was given both a callable and a block/,
      -> { SimpleFlow::Pipeline.new { parallel { step a, b } } } => /second callable/,
      -> { SimpleFlow::Pipeline.new { parallel { step(:x, a) { |r| r } } } } => /Step :x was given both/
    }

    cases.each do |build, message|
      error = assert_raises(ArgumentError) { build.call }
      assert_match message, error.message
    end
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
