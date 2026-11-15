# frozen_string_literal: true

require_relative 'test_helper'

module SimpleFlow
  # Issue #56: step names that Mermaid can't take as node ids get a generated
  # id and a quoted label; plain names are written unchanged
  class VisualizeMermaidIdsTest < Minitest::Test
    def mermaid(dependencies)
      DependencyGraphVisualizer.new(DependencyGraph.new(dependencies)).to_mermaid
    end

    def test_keyword_names_get_a_generated_id_and_quoted_label
      out = mermaid(start: [], end: [:start], other: [:start])

      assert_includes out, '  start[start] --> step_end["end"]'
      assert_includes out, '  class step_end group1'
      refute_match(/\bend\[end\]|class end\b/, out)
    end

    def test_names_with_spaces_or_quotes_are_quoted_and_escaped
      out = mermaid(start: [], 'fetch user': [:start], 'say "hi"': [:'fetch user'])

      assert_includes out, '  start[start] --> step_fetch_user["fetch user"]'
      assert_includes out, '  step_fetch_user["fetch user"] --> step_say__hi_["say #quot;hi#quot;"]'
    end

    def test_generated_ids_do_not_collide_with_other_steps
      out = mermaid(start: [], end: [:start], step_end: [:start])

      assert_includes out, '  start[start] --> step_end_2["end"]'
      assert_includes out, '  start[start] --> step_end[step_end]'
    end

    def test_plain_names_are_unchanged
      out = mermaid(start: [], 'fetch-user': [:start], save?: [:start], End: [:save?])

      assert_includes out, '  start[start] --> fetch-user[fetch-user]'
      assert_includes out, '  save?[save?] --> End[End]'
      assert_includes out, '  class fetch-user group1'
    end
  end
end
