# frozen_string_literal: true

module SimpleFlow
  ##
  # DependencyGraph manages steps with explicit dependencies and provides
  # automatic topological sorting and parallel execution order computation.
  #
  # This class implements dependency graph concepts inspired by Dagwood but
  # with a custom implementation tailored for SimpleFlow's needs.
  #
  # Features:
  # - Topological sorting (Kahn's algorithm)
  # - Automatic parallel execution order computation
  # - Cycle detection
  # - Graph composition (merge)
  # - Subgraph extraction
  #
  class DependencyGraph
    attr_reader :steps, :dependencies

    def initialize
      @steps = {}
      @dependencies = {}
    end

    ##
    # Add a step to the graph with optional dependencies
    #
    # @param name [Symbol] The name of the step
    # @param callable [Proc, Object] The callable to execute
    # @param depends_on [Array<Symbol>] Array of step names this step depends on
    # @return [self] for chaining
    #
    def add_step(name, callable, depends_on: [])
      raise ArgumentError, "Step name must be a Symbol" unless name.is_a?(Symbol)
      raise ArgumentError, "Callable must respond to #call" unless callable.respond_to?(:call)

      @steps[name] = callable
      @dependencies[name] = Array(depends_on)
      self
    end

    ##
    # Get the number of steps in the graph
    #
    def size
      @steps.size
    end

    ##
    # Check if the graph is empty
    #
    def empty?
      @steps.empty?
    end

    ##
    # Compute topological ordering of steps using Kahn's algorithm
    #
    # @return [Array<Symbol>] Ordered array of step names
    # @raise [CyclicDependencyError] if graph contains cycles
    #
    def order
      # Build in-degree map (count of dependencies for each node)
      in_degree = Hash.new(0)
      @steps.keys.each do |step|
        in_degree[step] ||= 0
        @dependencies[step]&.each do |dep|
          in_degree[step] += 1
        end
      end

      # Queue of nodes with no dependencies
      queue = @steps.keys.select { |step| in_degree[step].zero? }
      result = []

      while queue.any?
        # Process node with no dependencies
        node = queue.shift
        result << node

        # For each step that depends on this node, reduce its in-degree
        @dependencies.each do |step, deps|
          next unless deps.include?(node)

          in_degree[step] -= 1
          queue << step if in_degree[step].zero?
        end
      end

      # If we haven't processed all nodes, there's a cycle
      if result.size != @steps.size
        unprocessed = @steps.keys - result
        raise CyclicDependencyError, "Circular dependency detected involving: #{unprocessed.inspect}"
      end

      result
    end

    ##
    # Compute parallel execution order - groups steps that can run concurrently
    #
    # @return [Array<Array<Symbol>>] Array of arrays, where each sub-array contains
    #   steps that can execute in parallel
    #
    def parallel_order
      # Build reverse dependency map (who depends on whom)
      dependents = Hash.new { |h, k| h[k] = [] }
      @dependencies.each do |step, deps|
        deps.each do |dep|
          dependents[dep] << step
        end
      end

      # Track completion level for each step
      levels = {}
      in_degree = Hash.new(0)

      # Calculate in-degrees
      @steps.keys.each do |step|
        in_degree[step] = @dependencies[step]&.size || 0
      end

      # Process in levels
      result = []
      current_level = @steps.keys.select { |step| in_degree[step].zero? }

      while current_level.any?
        result << current_level.dup
        next_level = []

        current_level.each do |completed_step|
          # Mark step as completed at this level
          levels[completed_step] = result.size - 1

          # Check dependent steps
          dependents[completed_step].each do |dependent|
            in_degree[dependent] -= 1
            if in_degree[dependent].zero?
              next_level << dependent
            end
          end
        end

        current_level = next_level.uniq
      end

      # Verify all steps processed
      if result.flatten.size != @steps.size
        unprocessed = @steps.keys - result.flatten
        raise CyclicDependencyError, "Circular dependency detected involving: #{unprocessed.inspect}"
      end

      result
    end

    ##
    # Execute the graph in parallel order
    #
    # @param initial_result [Result] The initial result to pass through
    # @return [Result] The final result after all steps
    #
    def execute(initial_result)
      require_relative 'parallel_step'

      result = initial_result
      execution_order = parallel_order

      execution_order.each do |level|
        if level.size == 1
          # Single step - execute directly
          step_name = level.first
          result = @steps[step_name].call(result)
          return result unless result.respond_to?(:continue?) && result.continue?
        else
          # Multiple steps - execute in parallel
          parallel_step = ParallelStep.new
          level.each do |step_name|
            parallel_step.add_step(@steps[step_name])
          end
          result = parallel_step.call(result)
          return result unless result.respond_to?(:continue?) && result.continue?
        end
      end

      result
    end

    ##
    # Merge another dependency graph into this one
    #
    # @param other [DependencyGraph] Another graph to merge
    # @return [DependencyGraph] A new merged graph
    #
    def merge(other)
      merged = DependencyGraph.new

      # Add all steps from this graph
      @steps.each do |name, callable|
        merged.add_step(name, callable, depends_on: @dependencies[name] || [])
      end

      # Add all steps from other graph
      other.steps.each do |name, callable|
        if merged.steps.key?(name)
          # Step already exists - merge dependencies
          existing_deps = merged.dependencies[name] || []
          new_deps = other.dependencies[name] || []
          merged.dependencies[name] = (existing_deps + new_deps).uniq
        else
          merged.add_step(name, callable, depends_on: other.dependencies[name] || [])
        end
      end

      merged
    end

    ##
    # Extract a subgraph containing only the specified step and its dependencies
    #
    # @param step_name [Symbol] The step to extract
    # @return [DependencyGraph] A new graph with only the subgraph
    # @raise [ArgumentError] if step doesn't exist
    #
    def subgraph(step_name)
      raise ArgumentError, "Step #{step_name} does not exist" unless @steps.key?(step_name)

      # Collect all dependencies recursively
      collected = Set.new
      to_process = [step_name]

      while to_process.any?
        current = to_process.shift
        next if collected.include?(current)

        collected.add(current)
        deps = @dependencies[current] || []
        to_process.concat(deps)
      end

      # Build new graph with collected steps
      sub = DependencyGraph.new
      collected.each do |name|
        sub.add_step(name, @steps[name], depends_on: @dependencies[name] || [])
      end

      sub
    end

    ##
    # Generate Graphviz DOT format for visualization
    #
    # @param title [String] Optional title for the graph
    # @param options [Hash] Options for DOT generation
    # @option options [Boolean] :show_levels (false) Highlight parallel execution levels
    # @option options [String] :rankdir ('TB') Graph direction: TB (top-bottom), LR (left-right)
    # @return [String] DOT format string
    #
    def to_dot(title: 'SimpleFlow Pipeline', **options)
      show_levels = options.fetch(:show_levels, false)
      rankdir = options.fetch(:rankdir, 'TB')

      dot = []
      dot << "digraph \"#{title}\" {"
      dot << "  rankdir=#{rankdir};"
      dot << "  node [shape=box, style=rounded];"
      dot << ""

      if show_levels && !empty?
        # Group nodes by execution level and color them
        levels = parallel_order
        colors = %w[lightblue lightgreen lightyellow lightpink lightcyan]

        levels.each_with_index do |level, idx|
          color = colors[idx % colors.length]
          level.each do |step_name|
            dot << "  #{step_name} [label=\"#{step_name}\", fillcolor=#{color}, style=\"rounded,filled\"];"
          end
        end
      else
        # Simple node declarations
        @steps.keys.each do |step_name|
          dot << "  #{step_name} [label=\"#{step_name}\"];"
        end
      end

      dot << ""

      # Add edges for dependencies
      @dependencies.each do |step, deps|
        deps.each do |dep|
          dot << "  #{dep} -> #{step};"
        end
      end

      dot << "}"
      dot.join("\n")
    end
  end

  ##
  # Error raised when a circular dependency is detected
  #
  class CyclicDependencyError < StandardError; end
end
