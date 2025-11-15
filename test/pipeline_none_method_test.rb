# frozen_string_literal: true

require_relative 'test_helper'

class PipelineNoneMethodTest < Minitest::Test
  include SimpleFlow

  # Test that the none method returns an empty array
  def test_none_method_returns_empty_array
    pipeline = Pipeline.new
    assert_equal [], pipeline.none
  end

  # Test using none method in step definition
  def test_step_with_none_method
    pipeline = Pipeline.new do
      step :step_a, ->(result) {
        result.with_context(:a, :done).continue(result.value)
      }, depends_on: none

      step :step_b, ->(result) {
        result.with_context(:b, :done).continue(result.value)
      }, depends_on: [:step_a]
    end

    result = pipeline.call_parallel(Result.new(nil))

    assert result.continue?
    assert_equal :done, result.context[:a]
    assert_equal :done, result.context[:b]
  end

  # Test that none and [] are equivalent
  def test_none_equivalent_to_empty_array
    pipeline_with_none = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value + 1) }, depends_on: none
    end

    pipeline_with_array = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value + 1) }, depends_on: []
    end

    result1 = pipeline_with_none.call_parallel(Result.new(5))
    result2 = pipeline_with_array.call_parallel(Result.new(5))

    assert_equal result1.value, result2.value
    assert_equal 6, result1.value
  end

  # Test multiple steps with none method
  def test_multiple_steps_with_none_method
    pipeline = Pipeline.new do
      step :validate, ->(result) {
        result.with_context(:validated, true).continue(result.value)
      }, depends_on: none

      step :fetch_a, ->(result) {
        result.with_context(:a, 10).continue(result.value)
      }, depends_on: [:validate]

      step :fetch_b, ->(result) {
        result.with_context(:b, 20).continue(result.value)
      }, depends_on: [:validate]

      step :merge, ->(result) {
        total = result.context[:a] + result.context[:b]
        result.continue(total)
      }, depends_on: [:fetch_a, :fetch_b]
    end

    result = pipeline.call_parallel(Result.new(0))

    assert result.continue?
    assert_equal 30, result.value
    assert result.context[:validated]
  end

  # Test dependency graph with none method
  def test_dependency_graph_with_none_method
    pipeline = Pipeline.new do
      step :root, ->(result) { result.continue(result.value) }, depends_on: none
      step :child, ->(result) { result.continue(result.value) }, depends_on: [:root]
    end

    graph = pipeline.dependency_graph

    assert_equal [], graph.dependencies[:root]
    assert_equal [:root], graph.dependencies[:child]
  end

  # Test mixing none and empty array
  def test_mixing_none_and_empty_array
    pipeline = Pipeline.new do
      step :step_a, ->(result) {
        result.with_context(:a, 1).continue(result.value)
      }, depends_on: none

      step :step_b, ->(result) {
        result.with_context(:b, 2).continue(result.value)
      }, depends_on: []

      step :step_c, ->(result) {
        result.continue(result.value)
      }, depends_on: [:step_a, :step_b]
    end

    result = pipeline.call_parallel(Result.new(nil))

    assert result.continue?
    assert_equal 1, result.context[:a]
    assert_equal 2, result.context[:b]
  end

  # Test none method in execution plan
  def test_none_method_in_execution_plan
    pipeline = Pipeline.new do
      step :start, ->(result) { result.continue(result.value) }, depends_on: none
      step :middle, ->(result) { result.continue(result.value) }, depends_on: [:start]
      step :end, ->(result) { result.continue(result.value) }, depends_on: [:middle]
    end

    plan = pipeline.execution_plan

    # Verify the execution plan includes all steps
    assert_includes plan, "start"
    assert_includes plan, "middle"
    assert_includes plan, "end"
  end
end
