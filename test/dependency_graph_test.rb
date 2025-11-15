# frozen_string_literal: true

require_relative 'test_helper'

module SimpleFlow
  class DependencyGraphTest < Minitest::Test
    def test_initialize_empty
      graph = DependencyGraph.new({})
      assert_empty graph.dependencies
    end

    def test_initialize_with_dependencies
      deps = { a: [:b], b: [:c], c: [] }
      graph = DependencyGraph.new(deps)

      assert_equal [:b], graph.dependencies[:a]
      assert_equal [:c], graph.dependencies[:b]
      assert_equal [], graph.dependencies[:c]
    end

    def test_initialize_normalizes_nil_to_empty_array
      graph = DependencyGraph.new({ a: nil, b: [] })

      assert_equal [], graph.dependencies[:a]
      assert_equal [], graph.dependencies[:b]
    end

    def test_initialize_converts_values_to_arrays
      graph = DependencyGraph.new({ a: :b, c: :d })

      assert_equal [:b], graph.dependencies[:a]
      assert_equal [:d], graph.dependencies[:c]
    end

    def test_initialize_sorts_dependencies
      graph = DependencyGraph.new({ a: [:z, :m, :a] })

      assert_equal [:a, :m, :z], graph.dependencies[:a]
    end

    def test_order_simple_linear
      graph = DependencyGraph.new({
        a: [:b],
        b: [:c],
        c: []
      })

      assert_equal [:c, :b, :a], graph.order
    end

    def test_order_diamond_shape
      graph = DependencyGraph.new({
        a: [:b, :c],
        b: [:d],
        c: [:d],
        d: []
      })

      order = graph.order
      assert_equal 4, order.size
      assert_equal :d, order.first
      assert_equal :a, order.last
      assert order.index(:b) > order.index(:d)
      assert order.index(:c) > order.index(:d)
    end

    def test_order_complex_graph
      graph = DependencyGraph.new({
        validate: [],
        fetch_user: [:validate],
        fetch_orders: [:fetch_user],
        fetch_products: [:fetch_user],
        calculate_total: [:fetch_orders, :fetch_products],
        process_payment: [:calculate_total]
      })

      order = graph.order
      assert_equal 6, order.size
      assert_equal :validate, order.first
      assert_equal :process_payment, order.last
    end

    def test_order_is_cached
      graph = DependencyGraph.new({ a: [:b], b: [] })

      order1 = graph.order
      order2 = graph.order

      assert_same order1, order2
    end

    def test_reverse_order
      graph = DependencyGraph.new({
        a: [:b],
        b: [:c],
        c: []
      })

      assert_equal [:a, :b, :c], graph.reverse_order
    end

    def test_reverse_order_is_cached
      graph = DependencyGraph.new({ a: [:b], b: [] })

      reverse1 = graph.reverse_order
      reverse2 = graph.reverse_order

      assert_same reverse1, reverse2
    end

    def test_parallel_order_independent_steps
      graph = DependencyGraph.new({
        a: [],
        b: [],
        c: []
      })

      parallel = graph.parallel_order
      assert_equal 1, parallel.size
      assert_equal [:a, :b, :c], parallel.first
    end

    def test_parallel_order_linear_chain
      graph = DependencyGraph.new({
        a: [:b],
        b: [:c],
        c: []
      })

      parallel = graph.parallel_order
      assert_equal [[:c], [:b], [:a]], parallel
    end

    def test_parallel_order_diamond_pattern
      graph = DependencyGraph.new({
        validate: [],
        fetch_orders: [:validate],
        fetch_products: [:validate],
        calculate_total: [:fetch_orders, :fetch_products]
      })

      parallel = graph.parallel_order
      assert_equal 3, parallel.size
      assert_equal [:validate], parallel[0]
      assert_equal [:fetch_orders, :fetch_products], parallel[1]
      assert_equal [:calculate_total], parallel[2]
    end

    def test_parallel_order_complex_ecommerce
      graph = DependencyGraph.new({
        validate_order: [],
        check_inventory: [:validate_order],
        calculate_shipping: [:validate_order],
        calculate_totals: [:check_inventory, :calculate_shipping],
        process_payment: [:calculate_totals],
        reserve_inventory: [:process_payment],
        create_shipment: [:reserve_inventory],
        send_email: [:create_shipment],
        send_sms: [:create_shipment]
      })

      parallel = graph.parallel_order

      # Validate order runs first
      assert_equal [:validate_order], parallel[0]

      # Check inventory and calculate shipping can run in parallel
      assert_equal [:calculate_shipping, :check_inventory], parallel[1]

      # Final notifications can run in parallel
      last_group = parallel.last
      assert_includes last_group, :send_email
      assert_includes last_group, :send_sms
    end

    def test_subgraph_returns_empty_for_nonexistent_node
      graph = DependencyGraph.new({ a: [:b], b: [] })
      subgraph = graph.subgraph(:nonexistent)

      assert_empty subgraph.dependencies
    end

    def test_subgraph_simple
      graph = DependencyGraph.new({
        a: [:b],
        b: [:c],
        c: [],
        d: []
      })

      subgraph = graph.subgraph(:a)

      assert_equal 3, subgraph.dependencies.size
      assert_equal [:b], subgraph.dependencies[:a]
      assert_equal [:c], subgraph.dependencies[:b]
      assert_equal [], subgraph.dependencies[:c]
      refute subgraph.dependencies.key?(:d)
    end

    def test_subgraph_includes_all_transitive_dependencies
      graph = DependencyGraph.new({
        a: [:b, :c],
        b: [:d],
        c: [:e],
        d: [:f],
        e: [],
        f: [],
        g: []
      })

      subgraph = graph.subgraph(:a)

      assert_equal 6, subgraph.dependencies.size
      assert subgraph.dependencies.key?(:a)
      assert subgraph.dependencies.key?(:b)
      assert subgraph.dependencies.key?(:c)
      assert subgraph.dependencies.key?(:d)
      assert subgraph.dependencies.key?(:e)
      assert subgraph.dependencies.key?(:f)
      refute subgraph.dependencies.key?(:g)
    end

    def test_subgraph_leaf_node
      graph = DependencyGraph.new({
        a: [:b],
        b: []
      })

      subgraph = graph.subgraph(:b)

      assert_equal 1, subgraph.dependencies.size
      assert_equal [], subgraph.dependencies[:b]
    end

    def test_merge_empty_graphs
      graph1 = DependencyGraph.new({})
      graph2 = DependencyGraph.new({})

      merged = graph1.merge(graph2)

      assert_empty merged.dependencies
    end

    def test_merge_non_overlapping
      graph1 = DependencyGraph.new({ a: [:b], b: [] })
      graph2 = DependencyGraph.new({ c: [:d], d: [] })

      merged = graph1.merge(graph2)

      assert_equal 4, merged.dependencies.size
      assert_equal [:b], merged.dependencies[:a]
      assert_equal [], merged.dependencies[:b]
      assert_equal [:d], merged.dependencies[:c]
      assert_equal [], merged.dependencies[:d]
    end

    def test_merge_overlapping_same_dependencies
      graph1 = DependencyGraph.new({ a: [:b], b: [] })
      graph2 = DependencyGraph.new({ a: [:b], c: [] })

      merged = graph1.merge(graph2)

      assert_equal 3, merged.dependencies.size
      assert_equal [:b], merged.dependencies[:a]
    end

    def test_merge_overlapping_different_dependencies
      graph1 = DependencyGraph.new({ a: [:b] })
      graph2 = DependencyGraph.new({ a: [:c] })

      merged = graph1.merge(graph2)

      assert_equal 1, merged.dependencies.size
      assert_equal 2, merged.dependencies[:a].size
      assert_includes merged.dependencies[:a], :b
      assert_includes merged.dependencies[:a], :c
    end

    def test_merge_complex
      graph1 = DependencyGraph.new({
        a: [:b, :c],
        b: [:d],
        c: []
      })

      graph2 = DependencyGraph.new({
        a: [:c, :e],
        d: [:f],
        e: []
      })

      merged = graph1.merge(graph2)

      # a should have union of both dependency lists (:c appears in both, so 3 unique)
      assert_equal 3, merged.dependencies[:a].size
      assert_includes merged.dependencies[:a], :b
      assert_includes merged.dependencies[:a], :c
      assert_includes merged.dependencies[:a], :e

      # Other dependencies should be preserved
      assert_equal [:d], merged.dependencies[:b]
      assert_equal [:f], merged.dependencies[:d]
      assert_equal [], merged.dependencies[:e]
    end

    def test_merge_preserves_original_graphs
      graph1 = DependencyGraph.new({ a: [:b] })
      graph2 = DependencyGraph.new({ a: [:c] })

      merged = graph1.merge(graph2)

      # Original graphs unchanged
      assert_equal [:b], graph1.dependencies[:a]
      assert_equal [:c], graph2.dependencies[:a]

      # Merged has both
      assert_equal 2, merged.dependencies[:a].size
    end

    def test_default_value_for_missing_keys
      graph = DependencyGraph.new({ a: [:b] })

      # Missing keys should return empty array
      assert_equal [], graph.dependencies[:nonexistent]
    end

    def test_cyclic_dependency_detection
      # TSort will raise an error for cyclic dependencies
      graph = DependencyGraph.new({
        a: [:b],
        b: [:c],
        c: [:a]
      })

      assert_raises(TSort::Cyclic) do
        graph.order
      end
    end

    def test_single_node_with_no_dependencies
      graph = DependencyGraph.new({
        a: []
      })

      assert_equal [:a], graph.order
      assert_equal [[:a]], graph.parallel_order
    end
  end
end
