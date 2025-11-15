require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class ParallelExecutionTest < Minitest::Test
    def setup
      @initial_result = Result.new(0)
    end

    # Test explicit parallel blocks
    def test_explicit_parallel_block
      execution_order = []

      pipeline = Pipeline.new do
        step ->(result) {
          execution_order << :step1
          result.continue(result.value + 1)
        }

        parallel do
          step ->(result) {
            execution_order << :parallel_a
            result.continue(result.value + 10)
          }
          step ->(result) {
            execution_order << :parallel_b
            result.continue(result.value + 100)
          }
        end

        step ->(result) {
          execution_order << :step3
          result.continue(result.value + 1000)
        }
      end

      result = pipeline.call(@initial_result)

      # Check that step1 runs first, parallel steps run together, step3 runs last
      assert_equal :step1, execution_order.first
      assert_includes execution_order, :parallel_a
      assert_includes execution_order, :parallel_b
      assert_equal :step3, execution_order.last
    end

    # Test named steps with automatic parallel detection
    def test_named_steps_with_dependencies
      pipeline = Pipeline.new do
        step :fetch_user, ->(result) {
          result.with_context(:user, "User1").continue(result.value + 1)
        }, depends_on: []

        step :fetch_orders, ->(result) {
          result.with_context(:orders, "Orders").continue(result.value + 10)
        }, depends_on: [:fetch_user]

        step :fetch_products, ->(result) {
          result.with_context(:products, "Products").continue(result.value + 100)
        }, depends_on: [:fetch_user]

        step :calculate_total, ->(result) {
          result.with_context(:total, "Total").continue(result.value + 1000)
        }, depends_on: [:fetch_orders, :fetch_products]
      end

      result = pipeline.call_parallel(@initial_result)

      assert_equal "User1", result.context[:user]
      assert_equal "Orders", result.context[:orders]
      assert_equal "Products", result.context[:products]
      assert_equal "Total", result.context[:total]
    end

    # Test that parallel execution respects halt
    def test_parallel_execution_respects_halt
      pipeline = Pipeline.new do
        parallel do
          step ->(result) {
            result.halt.with_error(:validation, "Failed validation")
          }
          step ->(result) {
            result.continue(result.value + 100)
          }
        end

        step ->(result) {
          result.continue(result.value + 1000)
        }
      end

      result = pipeline.call(@initial_result)

      refute result.continue?
      assert_includes result.errors[:validation], "Failed validation"
    end

    # Test backward compatibility - old API still works
    def test_backward_compatibility
      pipeline = Pipeline.new do
        step ->(result) { result.continue(result.value + 1) }
        step ->(result) { result.continue(result.value * 2) }
      end

      result = pipeline.call(@initial_result)
      assert_equal 2, result.value
    end

    # Test dependency graph detection
    def test_dependency_graph_parallel_detection
      graph = DependencyGraph.new(
        fetch_user: [],
        fetch_orders: [:fetch_user],
        fetch_products: [:fetch_user],
        calculate_total: [:fetch_orders, :fetch_products]
      )

      parallel_order = graph.parallel_order

      assert_equal 3, parallel_order.size
      assert_equal [:fetch_user], parallel_order[0]
      assert_equal [:fetch_orders, :fetch_products].sort, parallel_order[1].sort
      assert_equal [:calculate_total], parallel_order[2]
    end

    # Test mixed named and unnamed steps
    def test_mixed_step_types
      execution_order = []

      pipeline = Pipeline.new do
        step ->(result) {
          execution_order << :unnamed1
          result.continue(result.value + 1)
        }

        step :named_step, ->(result) {
          execution_order << :named
          result.continue(result.value + 10)
        }, depends_on: []

        step ->(result) {
          execution_order << :unnamed2
          result.continue(result.value + 100)
        }
      end

      result = pipeline.call(@initial_result)

      assert_equal [:unnamed1, :named, :unnamed2], execution_order
      assert_equal 111, result.value
    end

    # Test async availability detection
    def test_async_availability
      pipeline = Pipeline.new

      # Should return boolean
      assert [true, false].include?(pipeline.async_available?)
    end

    # Test complex dependency graph
    def test_complex_dependency_graph
      graph = DependencyGraph.new(
        a: [],
        b: [],
        c: [:a],
        d: [:a, :b],
        e: [:c, :d]
      )

      parallel_order = graph.parallel_order

      # a and b can run in parallel
      assert_equal [:a, :b].sort, parallel_order[0].sort

      # c and d can run in parallel after a and b
      assert_equal [:c, :d].sort, parallel_order[1].sort

      # e must run last
      assert_equal [:e], parallel_order[2]
    end

    # Test subgraph extraction
    def test_subgraph
      graph = DependencyGraph.new(
        a: [],
        b: [:a],
        c: [:b],
        d: [:a]
      )

      subgraph = graph.subgraph(:c)

      assert_equal 3, subgraph.dependencies.size
      assert_includes subgraph.dependencies.keys, :c
      assert_includes subgraph.dependencies.keys, :b
      assert_includes subgraph.dependencies.keys, :a
    end

    # Test merging dependency graphs
    def test_merge_graphs
      graph1 = DependencyGraph.new(
        a: [],
        b: [:a]
      )

      graph2 = DependencyGraph.new(
        c: [:a],
        b: [:a, :d],
        d: []
      )

      merged = graph1.merge(graph2)

      assert_equal 4, merged.dependencies.keys.size
      assert_equal [:a, :d].sort, merged.dependencies[:b].sort
    end
  end
end
