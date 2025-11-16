# frozen_string_literal: true

require_relative 'test_helper'

class NamedParallelTest < Minitest::Test
  include SimpleFlow

  # Test basic named parallel group
  def test_named_parallel_group
    pipeline = Pipeline.new do
      parallel :fetch_data, depends_on: :none do
        step :fetch_orders, ->(result) {
          result.with_context(:orders, [1, 2, 3]).continue(result.value)
        }
        step :fetch_products, ->(result) {
          result.with_context(:products, [:a, :b, :c]).continue(result.value)
        }
      end
    end

    # Verify parallel group is tracked
    assert_equal [:fetch_orders, :fetch_products], pipeline.parallel_groups[:fetch_data][:steps]
    assert_equal [], pipeline.parallel_groups[:fetch_data][:dependencies]
  end

  # Test depending on a named parallel group
  def test_depend_on_parallel_group
    pipeline = Pipeline.new do
      parallel :fetch_data, depends_on: :none do
        step :fetch_orders, ->(result) {
          result.with_context(:orders, [1, 2, 3]).continue(result.value)
        }
        step :fetch_products, ->(result) {
          result.with_context(:products, [:a, :b, :c]).continue(result.value)
        }
      end

      step :process, ->(result) {
        total = result.context[:orders].size + result.context[:products].size
        result.continue(total)
      }, depends_on: :fetch_data
    end

    # Verify :process depends on all steps in :fetch_data group
    graph = pipeline.dependency_graph
    assert_equal [:fetch_orders, :fetch_products], graph.dependencies[:process].sort
  end

  # Test parallel group with dependencies
  def test_parallel_group_with_dependencies
    pipeline = Pipeline.new do
      step :validate, ->(result) {
        result.with_context(:validated, true).continue(result.value)
      }, depends_on: :none

      parallel :fetch_data, depends_on: :validate do
        step :fetch_orders, ->(result) {
          result.with_context(:orders, [1, 2, 3]).continue(result.value)
        }
        step :fetch_products, ->(result) {
          result.with_context(:products, [:a, :b, :c]).continue(result.value)
        }
      end
    end

    graph = pipeline.dependency_graph
    # Both steps in the parallel group should depend on :validate
    assert_equal [:validate], graph.dependencies[:fetch_orders]
    assert_equal [:validate], graph.dependencies[:fetch_products]
  end

  # Test execution with named parallel groups
  def test_execution_with_named_parallel
    pipeline = Pipeline.new do
      step :validate, ->(result) {
        result.with_context(:validated, true).continue(result.value)
      }, depends_on: :none

      parallel :fetch_data, depends_on: :validate do
        step :fetch_orders, ->(result) {
          result.with_context(:orders, [1, 2, 3]).continue(result.value)
        }
        step :fetch_products, ->(result) {
          result.with_context(:products, [:a, :b, :c]).continue(result.value)
        }
      end

      step :process, ->(result) {
        total = result.context[:orders].size + result.context[:products].size
        result.continue(total)
      }, depends_on: :fetch_data
    end

    result = pipeline.call_parallel(Result.new(0))

    assert result.continue?
    assert_equal 6, result.value
    assert result.context[:validated]
    assert_equal [1, 2, 3], result.context[:orders]
    assert_equal [:a, :b, :c], result.context[:products]
  end

  # Test that parallel group names cannot be :none or :nothing
  def test_parallel_group_reserved_names
    error = assert_raises(ArgumentError) do
      Pipeline.new do
        parallel :none do
          step :step_a, ->(result) { result.continue(result.value) }
        end
      end
    end

    assert_match(/reserved/i, error.message)
  end

  # Test multiple parallel groups
  def test_multiple_parallel_groups
    pipeline = Pipeline.new do
      parallel :group_a, depends_on: :none do
        step :step_a1, ->(result) { result.with_context(:a1, 1).continue(result.value) }
        step :step_a2, ->(result) { result.with_context(:a2, 2).continue(result.value) }
      end

      parallel :group_b, depends_on: :group_a do
        step :step_b1, ->(result) { result.with_context(:b1, 3).continue(result.value) }
        step :step_b2, ->(result) { result.with_context(:b2, 4).continue(result.value) }
      end

      step :final, ->(result) {
        sum = result.context[:a1] + result.context[:a2] + result.context[:b1] + result.context[:b2]
        result.continue(sum)
      }, depends_on: :group_b
    end

    graph = pipeline.dependency_graph
    # group_b steps should depend on all group_a steps
    assert_equal [:step_a1, :step_a2], graph.dependencies[:step_b1].sort
    assert_equal [:step_a1, :step_a2], graph.dependencies[:step_b2].sort
    # final should depend on all group_b steps
    assert_equal [:step_b1, :step_b2], graph.dependencies[:final].sort

    result = pipeline.call_parallel(Result.new(0))
    assert_equal 10, result.value
  end
end
