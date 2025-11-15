# frozen_string_literal: true

module SimpleFlow
  ##
  # DependencyGraphVisualizer generates visual representations of dependency graphs.
  # Supports ASCII art for terminal display and Graphviz DOT format for graph images.
  #
  # Example:
  #   graph = SimpleFlow::DependencyGraph.new(
  #     fetch_user: [],
  #     fetch_orders: [:fetch_user],
  #     fetch_products: [:fetch_user],
  #     calculate: [:fetch_orders, :fetch_products]
  #   )
  #
  #   visualizer = SimpleFlow::DependencyGraphVisualizer.new(graph)
  #   puts visualizer.to_ascii
  #   File.write('graph.dot', visualizer.to_dot)
  #
  class DependencyGraphVisualizer
    attr_reader :graph

    # @param graph [DependencyGraph] the dependency graph to visualize
    def initialize(graph)
      @graph = graph
    end

    # Generate ASCII art representation of the dependency graph
    # @param show_groups [Boolean] whether to show parallel execution groups
    # @return [String] ASCII art representation
    def to_ascii(show_groups: true)
      output = []
      output << "Dependency Graph"
      output << "=" * 60
      output << ""

      # Show dependencies
      output << "Dependencies:"
      @graph.dependencies.each do |step, deps|
        deps_str = deps.empty? ? "(none)" : deps.map { |d| ":#{d}" }.join(", ")
        output << "  :#{step}"
        output << "    └─ depends on: #{deps_str}"
      end
      output << ""

      # Show execution order
      output << "Execution Order (sequential):"
      order = @graph.order
      order.each_with_index do |step, idx|
        prefix = idx == 0 ? "  " : "  ↓ "
        output << "#{prefix}:#{step}"
      end
      output << ""

      if show_groups
        # Show parallel groups
        output << "Parallel Execution Groups:"
        parallel_groups = @graph.parallel_order
        parallel_groups.each_with_index do |group, idx|
          output << "  Group #{idx + 1}:"
          if group.size == 1
            output << "    └─ :#{group.first} (sequential)"
          else
            output << "    ├─ Parallel execution of #{group.size} steps:"
            group.each_with_index do |step, step_idx|
              prefix = step_idx == group.size - 1 ? "    └─" : "    ├─"
              output << "#{prefix} :#{step}"
            end
          end
        end
        output << ""

        # Show execution tree
        output << "Execution Tree:"
        output.concat(build_tree(parallel_groups))
      end

      output.join("\n")
    end

    # Generate Graphviz DOT format for the dependency graph
    # @param include_groups [Boolean] whether to color-code parallel groups
    # @param orientation [String] graph orientation: 'TB' (top-to-bottom), 'LR' (left-to-right)
    # @return [String] DOT format representation
    def to_dot(include_groups: true, orientation: 'TB')
      lines = []
      lines << "digraph DependencyGraph {"
      lines << "  rankdir=#{orientation};"
      lines << "  node [shape=box, style=rounded];"
      lines << ""

      if include_groups
        # Color-code parallel groups
        parallel_groups = @graph.parallel_order
        colors = ['lightblue', 'lightgreen', 'lightyellow', 'lightpink', 'lightgray']

        parallel_groups.each_with_index do |group, idx|
          color = colors[idx % colors.size]
          lines << "  // Group #{idx + 1}"
          group.each do |step|
            lines << "  #{step} [fillcolor=#{color}, style=\"rounded,filled\"];"
          end
        end
        lines << ""
      end

      # Add nodes and edges
      lines << "  // Dependencies"
      @graph.dependencies.each do |step, deps|
        if deps.empty?
          lines << "  #{step};"
        else
          deps.each do |dep|
            lines << "  #{dep} -> #{step};"
          end
        end
      end

      lines << ""
      lines << "  // Legend"
      if include_groups
        lines << "  subgraph cluster_legend {"
        lines << "    label=\"Parallel Groups\";"
        lines << "    style=dashed;"
        parallel_groups.each_with_index do |group, idx|
          next if group.empty?
          color = colors[idx % colors.size]
          lines << "    legend_#{idx} [label=\"Group #{idx + 1} (#{group.size} step#{'s' if group.size > 1})\", fillcolor=#{color}, style=\"rounded,filled\"];"
        end
        lines << "  }"
      end

      lines << "}"
      lines.join("\n")
    end

    # Generate Mermaid diagram format for the dependency graph
    # @return [String] Mermaid format representation
    def to_mermaid
      lines = []
      lines << "graph TD"

      @graph.dependencies.each do |step, deps|
        if deps.empty?
          lines << "  #{step}[#{step}]"
        else
          deps.each do |dep|
            lines << "  #{dep}[#{dep}] --> #{step}[#{step}]"
          end
        end
      end

      # Add styling for parallel groups
      parallel_groups = @graph.parallel_order
      parallel_groups.each_with_index do |group, idx|
        next if group.size <= 1
        lines << "  classDef group#{idx} fill:##{['9cf', '9f9', 'ff9', 'f9f', 'ccc'][idx % 5]}"
        group.each do |step|
          lines << "  class #{step} group#{idx}"
        end
      end

      lines.join("\n")
    end

    # Generate a simple text-based execution plan
    # @return [String] text execution plan
    def to_execution_plan
      output = []
      output << "Execution Plan"
      output << "=" * 60
      output << ""

      parallel_groups = @graph.parallel_order
      total_steps = @graph.dependencies.size

      output << "Total Steps: #{total_steps}"
      output << "Execution Phases: #{parallel_groups.size}"
      output << ""

      parallel_groups.each_with_index do |group, idx|
        output << "Phase #{idx + 1}:"
        if group.size == 1
          output << "  → Execute :#{group.first}"
        else
          output << "  ⚡ Execute in parallel:"
          group.each do |step|
            deps = @graph.dependencies[step]
            deps_str = deps.empty? ? "no dependencies" : "after #{deps.map { |d| ":#{d}" }.join(', ')}"
            output << "     • :#{step} (#{deps_str})"
          end
        end
        output << ""
      end

      # Calculate potential speedup
      sequential_cost = total_steps
      parallel_cost = parallel_groups.size
      speedup = (sequential_cost.to_f / parallel_cost).round(2)

      output << "Performance Estimate:"
      output << "  Sequential execution: #{sequential_cost} time units"
      output << "  Parallel execution: #{parallel_cost} time units"
      output << "  Potential speedup: #{speedup}x"

      output.join("\n")
    end

    # Generate HTML page with interactive visualization using vis.js
    # @param title [String] page title
    # @return [String] HTML page content
    def to_html(title: "Dependency Graph")
      parallel_groups = @graph.parallel_order
      nodes = []
      edges = []

      # Build nodes with group coloring
      group_colors = ['#A8D5FF', '#A8FFA8', '#FFFFA8', '#FFA8FF', '#D3D3D3']
      step_to_group = {}
      parallel_groups.each_with_index do |group, idx|
        group.each { |step| step_to_group[step] = idx }
      end

      @graph.dependencies.keys.each do |step|
        group_idx = step_to_group[step] || 0
        nodes << {
          id: step.to_s,
          label: step.to_s,
          color: group_colors[group_idx % group_colors.size],
          level: parallel_groups.index { |g| g.include?(step) }
        }
      end

      # Build edges
      @graph.dependencies.each do |step, deps|
        deps.each do |dep|
          edges << { from: dep.to_s, to: step.to_s }
        end
      end

      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>#{title}</title>
          <script type="text/javascript" src="https://unpkg.com/vis-network/standalone/umd/vis-network.min.js"></script>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            #graph { width: 100%; height: 600px; border: 1px solid #ddd; }
            .info { margin-top: 20px; padding: 15px; background: #f5f5f5; border-radius: 5px; }
            .legend { display: flex; gap: 20px; margin-top: 10px; }
            .legend-item { display: flex; align-items: center; gap: 5px; }
            .legend-color { width: 20px; height: 20px; border-radius: 3px; }
          </style>
        </head>
        <body>
          <h1>#{title}</h1>
          <div id="graph"></div>
          <div class="info">
            <h3>Execution Groups (Parallel)</h3>
            <div class="legend">
              #{parallel_groups.map.with_index { |group, idx|
                "<div class='legend-item'><div class='legend-color' style='background: #{group_colors[idx % group_colors.size]}'></div><span>Group #{idx + 1}: #{group.join(', ')}</span></div>"
              }.join("\n              ")}
            </div>
          </div>
          <script>
            var nodes = new vis.DataSet(#{nodes.to_json});
            var edges = new vis.DataSet(#{edges.to_json});
            var container = document.getElementById('graph');
            var data = { nodes: nodes, edges: edges };
            var options = {
              layout: {
                hierarchical: {
                  direction: 'UD',
                  sortMethod: 'directed',
                  levelSeparation: 150
                }
              },
              edges: {
                arrows: 'to',
                smooth: { type: 'cubicBezier' }
              },
              nodes: {
                shape: 'box',
                margin: 10,
                widthConstraint: { minimum: 100, maximum: 200 }
              },
              physics: {
                enabled: false
              }
            };
            var network = new vis.Network(container, data, options);
          </script>
        </body>
        </html>
      HTML

      html
    end

    private

    def build_tree(parallel_groups)
      output = []
      parallel_groups.each_with_index do |group, idx|
        is_last = idx == parallel_groups.size - 1

        if group.size == 1
          prefix = is_last ? "  └─" : "  ├─"
          output << "#{prefix} :#{group.first}"
        else
          prefix = is_last ? "  └─" : "  ├─"
          output << "#{prefix} [Parallel]"
          group.each_with_index do |step, step_idx|
            is_last_step = step_idx == group.size - 1
            connector = is_last ? "     " : "  │  "
            step_prefix = is_last_step ? "└─" : "├─"
            output << "#{connector}#{step_prefix} :#{step}"
          end
        end
      end
      output
    end
  end
end
