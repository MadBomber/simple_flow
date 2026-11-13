# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # Issue #36: step names that aren't plain DOT identifiers must be quoted.
  class VisualizeDotQuotingTest < Minitest::Test
    def pipeline
      Pipeline.new do
        step :'fetch-user', ->(r) { r.continue(1) }, depends_on: :none
        step :save?, ->(r) { r.continue(2) }, depends_on: [:'fetch-user']
        step :'say "hi"', ->(r) { r.continue(3) }, depends_on: [:save?]
      end
    end

    def test_non_identifier_names_are_quoted_in_nodes_and_edges
      dot = pipeline.visualize_dot

      assert_includes dot, '  "fetch-user" [fillcolor='
      assert_includes dot, '  "fetch-user" -> "save?";'
      refute_match(/^\s+fetch-user\b/, dot)
    end

    def test_quotes_and_backslashes_are_escaped
      dot = pipeline.visualize_dot

      assert_includes dot, '  "save?" -> "say \"hi\"";'
    end

    def test_names_with_no_dependencies_are_quoted_without_groups
      dot = pipeline.visualize_dot(include_groups: false)

      assert_includes dot, '  "fetch-user";'
    end

    def test_plain_identifiers_stay_unquoted
      plain = Pipeline.new do
        step :fetch_user, ->(r) { r.continue(1) }, depends_on: :none
        step :save, ->(r) { r.continue(2) }, depends_on: [:fetch_user]
      end

      dot = plain.visualize_dot

      assert_includes dot, '  fetch_user -> save;'
      refute_includes dot, '"fetch_user"'
    end

    def test_dot_keywords_are_quoted
      keywords = Pipeline.new do
        step :node, ->(r) { r.continue(1) }, depends_on: :none
        step :edge, ->(r) { r.continue(2) }, depends_on: [:node]
      end

      assert_includes keywords.visualize_dot, '  "node" -> "edge";'
    end

    def test_helper_escapes_backslash
      visualizer = DependencyGraphVisualizer.new(pipeline.dependency_graph)

      assert_equal '"a\\\\b"', visualizer.send(:dot_id, 'a\\b')
    end
  end
end
