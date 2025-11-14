# frozen_string_literal: true

module SimpleFlow
  ##
  # The Pipeline class facilitates the creation and execution of a sequence of steps (or operations),
  # with the possibility of inserting middleware to modify or handle the processing in a flexible way.
  # This allows for a clean and modular design where components can be easily added, removed, or replaced
  # without affecting the overall logic flow.
  #
  # Pipeline supports two execution modes:
  # 1. Manual mode: Use `parallel` blocks to explicitly group concurrent steps
  # 2. Automatic mode: Declare dependencies with `depends_on` for automatic parallelization
  #
  # Manual mode example:
  #   pipeline = SimpleFlow::Pipeline.new do
  #     step ->(result) { fetch_user(result) }
  #     parallel do
  #       step ->(result) { fetch_orders(result) }
  #       step ->(result) { fetch_preferences(result) }
  #     end
  #   end
  #
  # Automatic mode example:
  #   pipeline = SimpleFlow::Pipeline.new do
  #     step :fetch_user, method(:fetch_user_impl)
  #     step :fetch_orders, method(:fetch_orders_impl), depends_on: [:fetch_user]
  #     step :fetch_preferences, method(:fetch_prefs_impl), depends_on: [:fetch_user]
  #   end
  #
  class Pipeline
    attr_reader :steps, :middlewares, :dependency_graph

    # Initializes a new Pipeline object. A block can be provided to dynamically configure the pipeline,
    # allowing the addition of steps and middleware.
    def initialize(&config)
      @steps = []
      @middlewares = []
      @dependency_graph = nil
      instance_eval(&config) if block_given?
    end

    # Registers a middleware to be applied to each step. Middlewares can be provided as Proc objects or any
    # object that responds to `.new` with the callable to be wrapped and options hash.
    # @param [Proc, Class] middleware the middleware to be used
    # @param [Hash] options any options to be passed to the middleware upon initialization
    def use_middleware(middleware, options = {})
      @middlewares << [middleware, options]
    end

    # Adds a step to the pipeline.
    #
    # Can be used in two ways:
    #
    # 1. Anonymous step (original behavior):
    #    step ->(result) { result.continue(result.value + 1) }
    #
    # 2. Named step with optional dependencies:
    #    step :fetch_user, method(:fetch_user), depends_on: [:validate]
    #
    # @param [Symbol, Proc, Object] name_or_callable Step name (Symbol) or callable object
    # @param [Proc, Object] callable The callable if first arg is a name
    # @param [Array<Symbol>] depends_on Array of step names this step depends on
    # @param block [Block] Block to use as the step if no callable provided
    # @raise [ArgumentError] if step doesn't respond to call or invalid arguments
    # @return [self] so that calls can be chained
    def step(name_or_callable = nil, callable = nil, depends_on: [], &block)
      # Determine if this is a named step or anonymous step
      if name_or_callable.is_a?(Symbol)
        # Named step with dependencies - use dependency graph
        step_name = name_or_callable
        step_callable = callable || block

        raise ArgumentError, "Named step #{step_name} must have a callable" unless step_callable
        raise ArgumentError, "Step must respond to #call" unless step_callable.respond_to?(:call)

        # Initialize dependency graph if not already done
        @dependency_graph ||= DependencyGraph.new

        # Apply middleware and add to dependency graph
        wrapped_callable = apply_middleware(step_callable)
        @dependency_graph.add_step(step_name, wrapped_callable, depends_on: depends_on)
      else
        # Anonymous step (original behavior) - use manual steps array
        step_callable = name_or_callable || block

        raise ArgumentError, "Step must respond to #call" unless step_callable.respond_to?(:call)

        wrapped_callable = apply_middleware(step_callable)
        @steps << wrapped_callable
      end

      self
    end

    # Adds a parallel execution block to the pipeline. Steps defined within the block
    # will execute concurrently using the Async gem.
    #
    # This is the MANUAL approach to parallelization. For AUTOMATIC parallelization,
    # use named steps with `depends_on` instead.
    #
    # Example:
    #   pipeline = SimpleFlow::Pipeline.new do
    #     step ->(result) { fetch_user(result) }
    #     parallel do
    #       step ->(result) { fetch_orders(result) }
    #       step ->(result) { fetch_preferences(result) }
    #     end
    #     step ->(result) { aggregate_data(result) }
    #   end
    #
    # @param block [Block] a block containing steps to execute in parallel
    # @return [self] so that calls can be chained
    def parallel(&block)
      require_relative 'parallel_step'

      parallel_step = ParallelStep.new

      # Temporarily collect steps for parallel execution
      original_steps = @steps
      @steps = []

      # Execute the block to collect parallel steps
      instance_eval(&block)

      # Add collected steps to parallel_step with middleware applied
      @steps.each do |step|
        parallel_step.add_step(step)
      end

      # Restore original steps and add the parallel step
      @steps = original_steps
      @steps << parallel_step

      self
    end

    # Internal: Applies registered middlewares to a callable.
    # @param [Proc, Object] callable the target callable to wrap with middleware
    # @return [Object] the callable wrapped with all registered middleware
    def apply_middleware(callable)
      @middlewares.reverse_each do |middleware, options|
        if middleware.is_a?(Proc)
          callable = middleware.call(callable)
        else
          callable = middleware.new(callable, **options)
        end
      end
      callable
    end

    # Executes the pipeline with a given initial result.
    #
    # Automatically chooses execution mode:
    # - If dependency graph has steps, uses automatic dependency-based execution
    # - Otherwise, uses manual sequential/parallel execution
    #
    # @param result [Object] the initial data/input to be passed through the pipeline
    # @return [Object] the result of executing the pipeline
    def call(result)
      if @dependency_graph && !@dependency_graph.empty?
        # Use automatic dependency-based execution
        @dependency_graph.execute(result)
      else
        # Use manual sequential/parallel execution (original behavior)
        steps.reduce(result) do |res, step|
          res.respond_to?(:continue?) && !res.continue? ? res : step.call(res)
        end
      end
    end

    # Get the parallel execution order for dependency-based steps
    # Returns array of arrays where each sub-array contains steps that run in parallel
    # @return [Array<Array<Symbol>>] or nil if no dependency graph
    def parallel_order
      @dependency_graph&.parallel_order
    end

    # Get the sequential execution order for dependency-based steps
    # @return [Array<Symbol>] or nil if no dependency graph
    def order
      @dependency_graph&.order
    end

    # Merge this pipeline with another pipeline
    # Only works with dependency-based pipelines
    # @param [Pipeline] other Another pipeline to merge with
    # @return [Pipeline] A new merged pipeline
    # @raise [ArgumentError] if either pipeline doesn't use dependency graph
    def merge(other)
      raise ArgumentError, "Cannot merge: this pipeline has no dependency graph" unless @dependency_graph
      raise ArgumentError, "Cannot merge: other pipeline has no dependency graph" unless other.dependency_graph

      merged = Pipeline.new
      merged.instance_variable_set(:@dependency_graph, @dependency_graph.merge(other.dependency_graph))
      merged.instance_variable_set(:@middlewares, @middlewares + other.middlewares)
      merged
    end

    # Create a subgraph containing only the specified step and its dependencies
    # Only works with dependency-based pipelines
    # @param [Symbol] step_name The step to extract
    # @return [Pipeline] A new pipeline with only the subgraph
    # @raise [ArgumentError] if pipeline doesn't use dependency graph
    def subgraph(step_name)
      raise ArgumentError, "Cannot create subgraph: pipeline has no dependency graph" unless @dependency_graph

      sub_pipeline = Pipeline.new
      sub_pipeline.instance_variable_set(:@dependency_graph, @dependency_graph.subgraph(step_name))
      sub_pipeline.instance_variable_set(:@middlewares, @middlewares.dup)
      sub_pipeline
    end

    # Generate Graphviz DOT format for visualization
    # Only works with dependency-based pipelines
    # @param [String] title Title for the graph
    # @param [Hash] options Options passed to DependencyGraph#to_dot
    # @option options [Boolean] :show_levels (false) Highlight parallel execution levels with colors
    # @option options [String] :rankdir ('TB') Graph direction: TB (top-bottom), LR (left-right)
    # @return [String] DOT format string
    # @raise [ArgumentError] if pipeline doesn't use dependency graph
    #
    # @example Generate DOT file
    #   pipeline = SimpleFlow::Pipeline.new do
    #     step :fetch_user, method(:fetch_user)
    #     step :fetch_orders, method(:fetch_orders), depends_on: [:fetch_user]
    #   end
    #
    #   File.write('pipeline.dot', pipeline.to_dot)
    #   # Then run: dot -Tpng pipeline.dot -o pipeline.png
    #
    # @example With level highlighting
    #   dot = pipeline.to_dot(show_levels: true, title: 'My Workflow')
    #
    def to_dot(title: 'SimpleFlow Pipeline', **options)
      raise ArgumentError, "Cannot generate DOT: pipeline has no dependency graph" unless @dependency_graph

      @dependency_graph.to_dot(title: title, **options)
    end
  end
end
