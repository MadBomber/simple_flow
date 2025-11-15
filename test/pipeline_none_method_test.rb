# frozen_string_literal: true

require_relative 'test_helper'

class PipelineNoneMethodTest < Minitest::Test
  include SimpleFlow

  # Test that :none symbol is filtered from dependencies
  def test_none_symbol_filtered_from_dependencies
    pipeline = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value) }, depends_on: :none
    end

    assert_equal [], pipeline.dependency_graph.dependencies[:step_a]
  end

  # Test using :none symbol in step definition
  def test_step_with_none_symbol
    pipeline = Pipeline.new do
      step :step_a, ->(result) {
        result.with_context(:a, :done).continue(result.value)
      }, depends_on: :none

      step :step_b, ->(result) {
        result.with_context(:b, :done).continue(result.value)
      }, depends_on: [:step_a]
    end

    result = pipeline.call_parallel(Result.new(nil))

    assert result.continue?
    assert_equal :done, result.context[:a]
    assert_equal :done, result.context[:b]
  end

  # Test that :none and [] are equivalent
  def test_none_equivalent_to_empty_array
    pipeline_with_none = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value + 1) }, depends_on: :none
    end

    pipeline_with_array = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value + 1) }, depends_on: []
    end

    result1 = pipeline_with_none.call_parallel(Result.new(5))
    result2 = pipeline_with_array.call_parallel(Result.new(5))

    assert_equal result1.value, result2.value
    assert_equal 6, result1.value
  end

  # Test multiple steps with :none symbol
  def test_multiple_steps_with_none_symbol
    pipeline = Pipeline.new do
      step :validate, ->(result) {
        result.with_context(:validated, true).continue(result.value)
      }, depends_on: :none

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

  # Test dependency graph with :none symbol
  def test_dependency_graph_with_none_symbol
    pipeline = Pipeline.new do
      step :root, ->(result) { result.continue(result.value) }, depends_on: :none
      step :child, ->(result) { result.continue(result.value) }, depends_on: [:root]
    end

    graph = pipeline.dependency_graph

    assert_equal [], graph.dependencies[:root]
    assert_equal [:root], graph.dependencies[:child]
  end

  # Test mixing :none and empty array
  def test_mixing_none_and_empty_array
    pipeline = Pipeline.new do
      step :step_a, ->(result) {
        result.with_context(:a, 1).continue(result.value)
      }, depends_on: :none

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

  # Test :none symbol in execution plan
  def test_none_symbol_in_execution_plan
    pipeline = Pipeline.new do
      step :start, ->(result) { result.continue(result.value) }, depends_on: :none
      step :middle, ->(result) { result.continue(result.value) }, depends_on: [:start]
      step :end, ->(result) { result.continue(result.value) }, depends_on: [:middle]
    end

    plan = pipeline.execution_plan

    # Verify the execution plan includes all steps
    assert_includes plan, "start"
    assert_includes plan, "middle"
    assert_includes plan, "end"
  end

  # Test :nothing symbol is also filtered
  def test_nothing_symbol_filtered
    pipeline = Pipeline.new do
      step :step_a, ->(result) { result.continue(result.value) }, depends_on: :nothing
    end

    assert_equal [], pipeline.dependency_graph.dependencies[:step_a]
  end

  # Test filtering :none from dependency arrays
  def test_none_filtered_from_arrays
    pipeline = Pipeline.new do
      step :step_a, ->(result) { result.continue(1) }, depends_on: :none
      step :step_b, ->(result) { result.continue(2) }, depends_on: :none
      step :step_c, ->(result) { result.continue(3) }, depends_on: [:step_a, :none, :step_b]
    end

    graph = pipeline.dependency_graph
    assert_equal [:step_a, :step_b], graph.dependencies[:step_c]
  end

  # Test that :none cannot be used as a step name
  def test_none_reserved_step_name
    error = assert_raises(ArgumentError) do
      Pipeline.new do
        step :none, ->(result) { result.continue(result.value) }
      end
    end

    assert_match(/reserved/i, error.message)
  end

  # Test that :nothing cannot be used as a step name
  def test_nothing_reserved_step_name
    error = assert_raises(ArgumentError) do
      Pipeline.new do
        step :nothing, ->(result) { result.continue(result.value) }
      end
    end

    assert_match(/reserved/i, error.message)
  end
end
