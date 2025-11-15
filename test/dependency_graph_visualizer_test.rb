require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class DependencyGraphVisualizerTest < Minitest::Test
    def setup
      @simple_graph = DependencyGraph.new(
        a: [],
        b: [:a],
        c: [:a],
        d: [:b, :c]
      )

      @complex_graph = DependencyGraph.new(
        fetch_user: [],
        fetch_orders: [:fetch_user],
        fetch_products: [:fetch_user],
        fetch_reviews: [:fetch_user],
        calculate_stats: [:fetch_orders, :fetch_products],
        generate_report: [:calculate_stats, :fetch_reviews]
      )

      @simple_visualizer = DependencyGraphVisualizer.new(@simple_graph)
      @complex_visualizer = DependencyGraphVisualizer.new(@complex_graph)
    end

    def test_to_ascii_includes_dependencies
      ascii = @simple_visualizer.to_ascii

      assert_includes ascii, "Dependencies:"
      assert_includes ascii, ":a"
      assert_includes ascii, ":b"
      assert_includes ascii, ":c"
      assert_includes ascii, ":d"
      assert_includes ascii, "depends on: (none)"
      assert_includes ascii, "depends on: :a"
    end

    def test_to_ascii_includes_execution_order
      ascii = @simple_visualizer.to_ascii

      assert_includes ascii, "Execution Order (sequential):"
      assert_includes ascii, "↓"  # Arrow showing flow
    end

    def test_to_ascii_shows_parallel_groups
      ascii = @complex_visualizer.to_ascii

      assert_includes ascii, "Parallel Execution Groups:"
      assert_includes ascii, "Group 1:"
      assert_includes ascii, "Group 2:"
      assert_includes ascii, "Parallel execution of"
    end

    def test_to_ascii_shows_execution_tree
      ascii = @simple_visualizer.to_ascii

      assert_includes ascii, "Execution Tree:"
      assert_includes ascii, "[Parallel]"
    end

    def test_to_dot_generates_valid_syntax
      dot = @simple_visualizer.to_dot

      assert_includes dot, "digraph DependencyGraph {"
      assert_includes dot, "}"
      assert_includes dot, "rankdir="
      assert_includes dot, "node [shape=box"
    end

    def test_to_dot_includes_all_nodes
      dot = @simple_visualizer.to_dot

      assert_includes dot, "a"
      assert_includes dot, "b"
      assert_includes dot, "c"
      assert_includes dot, "d"
    end

    def test_to_dot_includes_edges
      dot = @simple_visualizer.to_dot

      assert_includes dot, "a -> b"
      assert_includes dot, "a -> c"
      assert_includes dot, "b -> d"
      assert_includes dot, "c -> d"
    end

    def test_to_dot_with_group_coloring
      dot = @complex_visualizer.to_dot(include_groups: true)

      assert_includes dot, "fillcolor="
      assert_includes dot, "// Group"
      assert_includes dot, "cluster_legend"
    end

    def test_to_dot_without_group_coloring
      dot = @complex_visualizer.to_dot(include_groups: false)

      refute_includes dot, "fillcolor="
      refute_includes dot, "cluster_legend"
    end

    def test_to_dot_orientation_tb
      dot = @simple_visualizer.to_dot(orientation: 'TB')
      assert_includes dot, "rankdir=TB"
    end

    def test_to_dot_orientation_lr
      dot = @simple_visualizer.to_dot(orientation: 'LR')
      assert_includes dot, "rankdir=LR"
    end

    def test_to_mermaid_generates_valid_syntax
      mermaid = @simple_visualizer.to_mermaid

      assert_includes mermaid, "graph TD"
      assert_includes mermaid, "-->"
    end

    def test_to_mermaid_includes_nodes_and_edges
      mermaid = @simple_visualizer.to_mermaid

      assert_includes mermaid, "a[a]"
      assert_includes mermaid, "b[b]"
      assert_includes mermaid, "a[a] --> b[b]"
    end

    def test_to_mermaid_includes_styling
      mermaid = @complex_visualizer.to_mermaid

      assert_includes mermaid, "classDef"
      assert_includes mermaid, "class"
    end

    def test_to_execution_plan_includes_summary
      plan = @simple_visualizer.to_execution_plan

      assert_includes plan, "Execution Plan"
      assert_includes plan, "Total Steps:"
      assert_includes plan, "Execution Phases:"
    end

    def test_to_execution_plan_shows_phases
      plan = @complex_visualizer.to_execution_plan

      assert_includes plan, "Phase 1:"
      assert_includes plan, "Phase 2:"
      assert_includes plan, "Execute in parallel:"
    end

    def test_to_execution_plan_shows_performance_estimate
      plan = @simple_visualizer.to_execution_plan

      assert_includes plan, "Performance Estimate:"
      assert_includes plan, "Sequential execution:"
      assert_includes plan, "Parallel execution:"
      assert_includes plan, "Potential speedup:"
    end

    def test_to_html_generates_valid_html
      html = @simple_visualizer.to_html

      assert_includes html, "<!DOCTYPE html>"
      assert_includes html, "<html>"
      assert_includes html, "</html>"
      assert_includes html, "vis-network"
    end

    def test_to_html_includes_graph_div
      html = @simple_visualizer.to_html

      assert_includes html, '<div id="graph">'
    end

    def test_to_html_includes_custom_title
      html = @simple_visualizer.to_html(title: "Custom Title")

      assert_includes html, "<title>Custom Title</title>"
      assert_includes html, "<h1>Custom Title</h1>"
    end

    def test_to_html_includes_legend
      html = @complex_visualizer.to_html

      assert_includes html, "Execution Groups"
      assert_includes html, "Group 1:"
      assert_includes html, "Group 2:"
    end

    def test_to_html_includes_nodes_and_edges_json
      html = @simple_visualizer.to_html

      assert_includes html, "var nodes"
      assert_includes html, "var edges"
      assert_includes html, "DataSet"
    end

    def test_visualizer_with_empty_graph
      empty_graph = DependencyGraph.new({})
      visualizer = DependencyGraphVisualizer.new(empty_graph)

      ascii = visualizer.to_ascii
      assert_includes ascii, "Dependencies:"

      dot = visualizer.to_dot
      assert_includes dot, "digraph DependencyGraph"
    end

    def test_visualizer_with_single_node
      single_graph = DependencyGraph.new(single: [])
      visualizer = DependencyGraphVisualizer.new(single_graph)

      ascii = visualizer.to_ascii
      assert_includes ascii, ":single"
      assert_includes ascii, "depends on: (none)"

      plan = visualizer.to_execution_plan
      assert_includes plan, "Total Steps: 1"
    end

    def test_visualizer_with_linear_graph
      linear_graph = DependencyGraph.new(
        step1: [],
        step2: [:step1],
        step3: [:step2],
        step4: [:step3]
      )
      visualizer = DependencyGraphVisualizer.new(linear_graph)

      plan = visualizer.to_execution_plan
      assert_includes plan, "Execution Phases: 4"
      assert_includes plan, "Potential speedup: 1.0x"  # No parallelism possible
    end
  end
end
