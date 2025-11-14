# frozen_string_literal: true

require 'test_helper'

module SimpleFlow
  class DependencyGraphTest < Minitest::Test
    def test_add_step
      graph = DependencyGraph.new
      step = ->(result) { result.continue(result.value + 1) }

      graph.add_step(:increment, step)

      assert_equal 1, graph.size
      assert_equal step, graph.steps[:increment]
    end

    def test_add_step_with_dependencies
      graph = DependencyGraph.new
      step1 = ->(result) { result.continue(result.value + 1) }
      step2 = ->(result) { result.continue(result.value * 2) }

      graph.add_step(:increment, step1)
      graph.add_step(:double, step2, depends_on: [:increment])

      assert_equal 2, graph.size
      assert_equal [:increment], graph.dependencies[:double]
    end

    def test_parallel_order_with_independent_steps
      graph = DependencyGraph.new
      step1 = ->(result) { result.continue(result.value) }
      step2 = ->(result) { result.continue(result.value) }

      graph.add_step(:step1, step1)
      graph.add_step(:step2, step2)

      parallel = graph.parallel_order
      assert_equal 1, parallel.length
      assert_equal 2, parallel[0].length
      assert_includes parallel[0], :step1
      assert_includes parallel[0], :step2
    end

    def test_parallel_order_with_dependencies
      graph = DependencyGraph.new

      graph.add_step(:fetch_user, ->(r) { r.continue(r.value) })
      graph.add_step(:fetch_orders, ->(r) { r.continue(r.value) }, depends_on: [:fetch_user])
      graph.add_step(:fetch_prefs, ->(r) { r.continue(r.value) }, depends_on: [:fetch_user])
      graph.add_step(:aggregate, ->(r) { r.continue(r.value) }, depends_on: [:fetch_orders, :fetch_prefs])

      parallel = graph.parallel_order

      assert_equal 3, parallel.length
      assert_equal [:fetch_user], parallel[0]
      assert_equal 2, parallel[1].length
      assert_includes parallel[1], :fetch_orders
      assert_includes parallel[1], :fetch_prefs
      assert_equal [:aggregate], parallel[2]
    end

    def test_order
      graph = DependencyGraph.new

      graph.add_step(:step1, ->(r) { r.continue(r.value) })
      graph.add_step(:step2, ->(r) { r.continue(r.value) }, depends_on: [:step1])
      graph.add_step(:step3, ->(r) { r.continue(r.value) }, depends_on: [:step2])

      order = graph.order

      assert_equal [:step1, :step2, :step3], order
    end

    def test_execute_sequential
      graph = DependencyGraph.new

      graph.add_step(:add_one, ->(result) { result.continue(result.value + 1) })
      graph.add_step(:double, ->(result) { result.continue(result.value * 2) }, depends_on: [:add_one])

      result = graph.execute(Result.new(5))

      assert_equal 12, result.value # (5 + 1) * 2
      assert result.continue?
    end

    def test_execute_with_parallel_steps
      graph = DependencyGraph.new
      execution_log = []

      graph.add_step(:base, ->(result) {
        execution_log << :base
        result.continue(result.value)
      })

      graph.add_step(:parallel1, ->(result) {
        execution_log << :parallel1
        result.with_context(:p1, true).continue(result.value)
      }, depends_on: [:base])

      graph.add_step(:parallel2, ->(result) {
        execution_log << :parallel2
        result.with_context(:p2, true).continue(result.value)
      }, depends_on: [:base])

      result = graph.execute(Result.new(42))

      assert_equal 42, result.value
      assert result.context[:p1]
      assert result.context[:p2]
      assert_equal :base, execution_log.first
    end

    def test_execute_halts_on_error
      graph = DependencyGraph.new

      graph.add_step(:step1, ->(result) { result.continue(result.value + 1) })
      graph.add_step(:step2, ->(result) { result.halt.with_error(:test, "Halted") }, depends_on: [:step1])
      graph.add_step(:step3, ->(result) { result.continue(result.value + 1) }, depends_on: [:step2])

      result = graph.execute(Result.new(5))

      refute result.continue?
      assert_includes result.errors[:test], "Halted"
    end

    def test_merge_graphs
      graph1 = DependencyGraph.new
      graph1.add_step(:step1, ->(r) { r.continue(r.value + 1) })
      graph1.add_step(:step2, ->(r) { r.continue(r.value + 1) }, depends_on: [:step1])

      graph2 = DependencyGraph.new
      graph2.add_step(:step3, ->(r) { r.continue(r.value + 1) })
      graph2.add_step(:step4, ->(r) { r.continue(r.value + 1) }, depends_on: [:step3])

      merged = graph1.merge(graph2)

      assert_equal 4, merged.size
      assert merged.steps.key?(:step1)
      assert merged.steps.key?(:step2)
      assert merged.steps.key?(:step3)
      assert merged.steps.key?(:step4)
    end

    def test_merge_with_overlapping_steps
      graph1 = DependencyGraph.new
      graph1.add_step(:shared, ->(r) { r.continue(r.value + 1) })
      graph1.add_step(:step1, ->(r) { r.continue(r.value) }, depends_on: [:shared])

      graph2 = DependencyGraph.new
      graph2.add_step(:shared, ->(r) { r.continue(r.value + 2) })
      graph2.add_step(:step2, ->(r) { r.continue(r.value) }, depends_on: [:shared])

      merged = graph1.merge(graph2)

      assert_equal 3, merged.size
      # Shared step should have both dependencies
      assert merged.dependencies.key?(:step1)
      assert merged.dependencies.key?(:step2)
    end

    def test_subgraph
      graph = DependencyGraph.new

      graph.add_step(:step1, ->(r) { r.continue(r.value + 1) })
      graph.add_step(:step2, ->(r) { r.continue(r.value * 2) }, depends_on: [:step1])
      graph.add_step(:step3, ->(r) { r.continue(r.value + 10) }, depends_on: [:step2])
      graph.add_step(:other, ->(r) { r.continue(r.value) })

      sub = graph.subgraph(:step2)

      assert_equal 2, sub.size
      assert sub.steps.key?(:step1)
      assert sub.steps.key?(:step2)
      refute sub.steps.key?(:step3)
      refute sub.steps.key?(:other)
    end

    def test_subgraph_with_nonexistent_step
      graph = DependencyGraph.new
      graph.add_step(:step1, ->(r) { r.continue(r.value) })

      assert_raises(ArgumentError) do
        graph.subgraph(:nonexistent)
      end
    end

    def test_empty_graph
      graph = DependencyGraph.new

      assert graph.empty?
      assert_equal 0, graph.size
    end
  end
end
