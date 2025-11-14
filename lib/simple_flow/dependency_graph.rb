# frozen_string_literal: true

require 'dagwood'

module SimpleFlow
  ##
  # DependencyGraph manages named steps with explicit dependencies and automatically
  # determines optimal execution order including parallel execution opportunities.
  #
  # This provides an alternative to manual `parallel` blocks by declaring dependencies
  # and letting the graph automatically detect which steps can run concurrently.
  #
  # Example:
  #   graph = SimpleFlow::DependencyGraph.new
  #   graph.add_step(:fetch_user, user_step)
  #   graph.add_step(:fetch_orders, orders_step, depends_on: [:fetch_user])
  #   graph.add_step(:fetch_prefs, prefs_step, depends_on: [:fetch_user])
  #
  #   # fetch_orders and fetch_prefs will automatically run in parallel
  #   result = graph.execute(initial_result)
  #
  class DependencyGraph
    attr_reader :steps, :dependencies

    def initialize
      @steps = {}
      @dependencies = {}
    end

    # Add a named step with optional dependencies
    # @param name [Symbol] The name of the step
    # @param callable [#call] The callable object (lambda, proc, method)
    # @param depends_on [Array<Symbol>] Array of step names this step depends on
    # @return [self]
    def add_step(name, callable, depends_on: [])
      @steps[name] = callable
      @dependencies[name] = depends_on
      self
    end

    # Check if any steps have been added
    # @return [Boolean]
    def empty?
      @steps.empty?
    end

    # Get the number of steps
    # @return [Integer]
    def size
      @steps.size
    end

    # Get parallel execution order using Dagwood
    # Returns array of arrays where each sub-array contains steps that can run in parallel
    # @return [Array<Array<Symbol>>]
    def parallel_order
      return [[]] if @dependencies.empty?

      # Handle steps with no dependencies (orphans)
      orphans = @steps.keys - @dependencies.keys
      graph_deps = @dependencies.dup

      # Add orphans with empty dependencies
      orphans.each { |name| graph_deps[name] ||= [] }

      # Create Dagwood graph and get parallel order
      dagwood_graph = Dagwood::DependencyGraph.new(graph_deps)
      dagwood_graph.parallel_order
    end

    # Get sequential execution order
    # @return [Array<Symbol>]
    def order
      return [] if @dependencies.empty?

      orphans = @steps.keys - @dependencies.keys
      graph_deps = @dependencies.dup
      orphans.each { |name| graph_deps[name] ||= [] }

      dagwood_graph = Dagwood::DependencyGraph.new(graph_deps)
      dagwood_graph.order
    end

    # Execute all steps in optimal order with automatic parallelization
    # @param initial_result [Result] The starting result
    # @return [Result] The final result after all steps complete
    def execute(initial_result)
      result = initial_result

      parallel_order.each do |level|
        break unless result.continue?

        if level.length == 1
          # Single step - execute sequentially
          step_name = level.first
          result = @steps[step_name].call(result)
        else
          # Multiple steps - execute in parallel
          parallel_step = ParallelStep.new(level.map { |name| @steps[name] })
          result = parallel_step.call(result)
        end
      end

      result
    end

    # Merge another dependency graph into this one
    # @param other [DependencyGraph] Another dependency graph
    # @return [DependencyGraph] A new merged graph
    def merge(other)
      merged = DependencyGraph.new

      # Merge steps
      @steps.each { |name, callable| merged.add_step(name, callable, depends_on: @dependencies[name] || []) }
      other.steps.each do |name, callable|
        # Union dependencies if step exists in both
        deps = (@dependencies[name] || []) | (other.dependencies[name] || [])
        merged.add_step(name, callable, depends_on: deps)
      end

      merged
    end

    # Create a subgraph containing only the specified step and its dependencies
    # @param step_name [Symbol] The step to extract dependencies for
    # @return [DependencyGraph] A new graph with only relevant steps
    def subgraph(step_name)
      raise ArgumentError, "Step #{step_name} not found" unless @steps.key?(step_name)

      # Find all recursive dependencies
      required_steps = find_dependencies(step_name)

      # Create new graph with only required steps
      sub = DependencyGraph.new
      required_steps.each do |name|
        # Only include dependencies that are also in the subgraph
        deps = (@dependencies[name] || []) & required_steps
        sub.add_step(name, @steps[name], depends_on: deps)
      end

      sub
    end

    private

    # Recursively find all dependencies for a given step
    # @param step_name [Symbol] The step name
    # @param visited [Set] Already visited steps (for cycle detection)
    # @return [Array<Symbol>] All required step names
    def find_dependencies(step_name, visited = Set.new)
      return [] if visited.include?(step_name)

      visited.add(step_name)
      deps = @dependencies[step_name] || []

      # Recursively find dependencies of dependencies
      all_deps = deps.flat_map { |dep| find_dependencies(dep, visited) }

      ([step_name] + all_deps).uniq
    end
  end
end
