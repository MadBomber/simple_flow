require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class PipelineVisualizationTest < Minitest::Test
    def setup
      @pipeline_with_deps = Pipeline.new do
        step :step_a, ->(result) { result.continue(result.value) }, depends_on: []
        step :step_b, ->(result) { result.continue(result.value) }, depends_on: [:step_a]
        step :step_c, ->(result) { result.continue(result.value) }, depends_on: [:step_a]
        step :step_d, ->(result) { result.continue(result.value) }, depends_on: [:step_b, :step_c]
      end

      @pipeline_without_deps = Pipeline.new do
        step ->(result) { result.continue(result.value) }
        step ->(result) { result.continue(result.value) }
      end
    end

    def test_dependency_graph_returns_graph_for_named_steps
      graph = @pipeline_with_deps.dependency_graph

      refute_nil graph
      assert_instance_of DependencyGraph, graph
      assert_equal 4, graph.dependencies.size
    end

    def test_dependency_graph_returns_nil_for_unnamed_steps
      graph = @pipeline_without_deps.dependency_graph

      assert_nil graph
    end

    def test_visualize_returns_visualizer_for_named_steps
      visualizer = @pipeline_with_deps.visualize

      refute_nil visualizer
      assert_instance_of DependencyGraphVisualizer, visualizer
    end

    def test_visualize_returns_nil_for_unnamed_steps
      visualizer = @pipeline_without_deps.visualize

      assert_nil visualizer
    end

    def test_visualize_ascii_returns_string_for_named_steps
      ascii = @pipeline_with_deps.visualize_ascii

      refute_nil ascii
      assert_instance_of String, ascii
      assert_includes ascii, "Dependencies:"
      assert_includes ascii, ":step_a"
      assert_includes ascii, ":step_b"
      assert_includes ascii, ":step_c"
      assert_includes ascii, ":step_d"
    end

    def test_visualize_ascii_returns_nil_for_unnamed_steps
      ascii = @pipeline_without_deps.visualize_ascii

      assert_nil ascii
    end

    def test_visualize_ascii_respects_show_groups_parameter
      ascii_with_groups = @pipeline_with_deps.visualize_ascii(show_groups: true)
      ascii_without_groups = @pipeline_with_deps.visualize_ascii(show_groups: false)

      assert_includes ascii_with_groups, "Parallel Execution Groups:"
      refute_includes ascii_without_groups, "Parallel Execution Groups:"
    end

    def test_visualize_dot_returns_string_for_named_steps
      dot = @pipeline_with_deps.visualize_dot

      refute_nil dot
      assert_instance_of String, dot
      assert_includes dot, "digraph DependencyGraph"
      assert_includes dot, "step_a"
      assert_includes dot, "step_a -> step_b"
    end

    def test_visualize_dot_returns_nil_for_unnamed_steps
      dot = @pipeline_without_deps.visualize_dot

      assert_nil dot
    end

    def test_visualize_dot_respects_include_groups_parameter
      dot_with_groups = @pipeline_with_deps.visualize_dot(include_groups: true)
      dot_without_groups = @pipeline_with_deps.visualize_dot(include_groups: false)

      assert_includes dot_with_groups, "fillcolor="
      refute_includes dot_without_groups, "fillcolor="
    end

    def test_visualize_dot_respects_orientation_parameter
      dot_tb = @pipeline_with_deps.visualize_dot(orientation: 'TB')
      dot_lr = @pipeline_with_deps.visualize_dot(orientation: 'LR')

      assert_includes dot_tb, "rankdir=TB"
      assert_includes dot_lr, "rankdir=LR"
    end

    def test_visualize_mermaid_returns_string_for_named_steps
      mermaid = @pipeline_with_deps.visualize_mermaid

      refute_nil mermaid
      assert_instance_of String, mermaid
      assert_includes mermaid, "graph TD"
      assert_includes mermaid, "step_a"
    end

    def test_visualize_mermaid_returns_nil_for_unnamed_steps
      mermaid = @pipeline_without_deps.visualize_mermaid

      assert_nil mermaid
    end

    def test_execution_plan_returns_string_for_named_steps
      plan = @pipeline_with_deps.execution_plan

      refute_nil plan
      assert_instance_of String, plan
      assert_includes plan, "Execution Plan"
      assert_includes plan, "Total Steps:"
      assert_includes plan, "Execution Phases:"
    end

    def test_execution_plan_returns_nil_for_unnamed_steps
      plan = @pipeline_without_deps.execution_plan

      assert_nil plan
    end

    def test_execution_plan_shows_parallel_opportunities
      plan = @pipeline_with_deps.execution_plan

      assert_includes plan, "Execute in parallel"
      assert_includes plan, "Potential speedup:"
    end

    def test_mixed_named_and_unnamed_steps
      mixed_pipeline = Pipeline.new do
        step ->(result) { result.continue(result.value) }  # unnamed
        step :named_step, ->(result) { result.continue(result.value) }, depends_on: []
        step ->(result) { result.continue(result.value) }  # unnamed
      end

      # Should still be able to visualize the named steps
      graph = mixed_pipeline.dependency_graph
      refute_nil graph
      assert_equal 1, graph.dependencies.size
    end

    def test_complex_dependency_pipeline_visualization
      complex_pipeline = Pipeline.new do
        step :extract_users, ->(r) { r.continue(r.value) }, depends_on: []
        step :extract_orders, ->(r) { r.continue(r.value) }, depends_on: []
        step :transform_users, ->(r) { r.continue(r.value) }, depends_on: [:extract_users]
        step :transform_orders, ->(r) { r.continue(r.value) }, depends_on: [:extract_orders]
        step :aggregate, ->(r) { r.continue(r.value) }, depends_on: [:transform_users, :transform_orders]
      end

      graph = complex_pipeline.dependency_graph
      parallel_groups = graph.parallel_order

      # 3 groups: [extract_*], [transform_*], [aggregate]
      assert_equal 3, parallel_groups.size
      assert_equal 2, parallel_groups[0].size  # extract_users and extract_orders in parallel
      assert_equal 2, parallel_groups[1].size  # transform_users and transform_orders in parallel
      assert_equal 1, parallel_groups[2].size  # aggregate runs alone
    end
  end
end
