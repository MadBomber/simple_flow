# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'

module SimpleFlow
  # to_html works when nothing else has loaded json. The suite itself cannot
  # show this because the async gem loads json as a side effect (issue #33)
  class VisualizerJsonTest < Minitest::Test
    LIB = File.expand_path('../lib', __dir__)

    SCRIPT = <<~RUBY
      require 'simple_flow/dependency_graph'
      require 'simple_flow/dependency_graph_visualizer'
      graph = SimpleFlow::DependencyGraph.new({ a: [], b: [:a] })
      html = SimpleFlow::DependencyGraphVisualizer.new(graph).to_html
      print html.include?('vis-network') ? 'ok' : 'no graph'
    RUBY

    def test_to_html_without_json_preloaded
      output, status = Open3.capture2e(Gem.ruby, '-I', LIB, '-e', SCRIPT)

      assert_predicate status, :success?, output
      assert_equal 'ok', output
    end
  end
end
