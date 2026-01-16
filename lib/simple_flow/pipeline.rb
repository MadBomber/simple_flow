module SimpleFlow
  ##
  # The Pipeline class facilitates the creation and execution of a sequence of steps (or operations),
  # with the possibility of inserting middleware to modify or handle the processing in a flexible way.
  # This allows for a clean and modular design where components can be easily added, removed, or replaced
  # without affecting the overall logic flow. It is particularly useful for scenarios where a set of operations
  # needs to be performed in a specific order, and you want to maintain the capability to inject additional
  # behavior (like logging, authorization, or input/output transformations) at any point in this sequence.
  #
  # Example Usage:
  # pipeline = SimpleFlow::Pipeline.new do
  #   use_middleware SomeMiddlewareClass, option: value
  #   step ->(input) { do_something_with(input) }
  #   step AnotherCallableObject
  # end
  #
  # result = pipeline.call(initial_data)
  #
  # Parallel Execution with Named Steps:
  # pipeline = SimpleFlow::Pipeline.new do
  #   step :fetch_user, ->(result) { ... }, depends_on: :none
  #   step :fetch_orders, ->(result) { ... }, depends_on: [:fetch_user]
  #   step :fetch_products, ->(result) { ... }, depends_on: [:fetch_user]
  #   step :calculate, ->(result) { ... }, depends_on: [:fetch_orders, :fetch_products]
  # end
  #
  # result = pipeline.call_parallel(initial_data)  # Auto-detects parallelism
  #
  # Note: You can use either depends_on: [] or depends_on: :none for clarity
  #
  # Explicit Parallel Blocks:
  # pipeline = SimpleFlow::Pipeline.new do
  #   step ->(result) { ... }
  #   parallel do
  #     step ->(result) { ... }
  #     step ->(result) { ... }
  #   end
  #   step ->(result) { ... }
  # end
  #
  class Pipeline
    attr_reader :steps, :middlewares, :named_steps, :step_dependencies, :concurrency, :parallel_groups, :optional_steps

    # Initializes a new Pipeline object. A block can be provided to dynamically configure the pipeline,
    # allowing the addition of steps and middleware.
    # @param concurrency [Symbol] concurrency model to use (:auto, :threads, :async)
    #   - :auto (default) - uses async if available, falls back to threads
    #   - :threads - always uses Ruby threads
    #   - :async - uses async gem (raises error if not available)
    def initialize(concurrency: :auto, &config)
      @steps = []
      @middlewares = []
      @named_steps = {}
      @step_dependencies = {}
      @parallel_groups = {}
      @optional_steps = Set.new
      @concurrency = concurrency

      validate_concurrency!

      instance_eval(&config) if block_given?
    end

    # Registers a middleware to be applied to each step. Middlewares can be provided as Proc objects or any
    # object that responds to `.new` with the callable to be wrapped and options hash.
    # @param [Proc, Class] middleware the middleware to be used
    # @param [Hash] options any options to be passed to the middleware upon initialization
    def use_middleware(middleware, options = {})
      @middlewares << [middleware, options]
    end

    # Adds a step to the pipeline. Supports both named and unnamed steps.
    #
    # Named steps with dependencies (for automatic parallel detection):
    #   step :fetch_user, ->(result) { ... }, depends_on: []
    #   step :process_data, ->(result) { ... }, depends_on: [:fetch_user]
    #
    # Unnamed steps (traditional usage):
    #   step ->(result) { ... }
    #   step { |result| ... }
    #
    # @param [Symbol, Proc, Object] name_or_callable step name (Symbol) or callable object
    # @param [Proc, Object] callable an object responding to call (if first param is a name)
    # @param [Hash] options options including :depends_on for dependency declaration
    # @param block [Block] a block to use as the step if no callable is provided
    # @raise [ArgumentError] if neither a callable nor block is given, or if the provided object does not respond to call
    # @return [self] so that calls can be chained
    def step(name_or_callable = nil, callable = nil, depends_on: [], &block)
      # Handle different calling patterns
      if name_or_callable.is_a?(Symbol)
        # Named step: step :name, ->(result) { ... }, depends_on: [...]
        name = name_or_callable
        callable ||= block

        # Validate step name
        if [:none, :nothing, :optional].include?(name)
          raise ArgumentError, "Step name '#{name}' is reserved. Please use a different name."
        end

        raise ArgumentError, "Step must respond to #call" unless callable.respond_to?(:call)

        callable = apply_middleware(callable)
        @named_steps[name] = callable

        # Check if this is an optional step
        if depends_on == :optional
          @optional_steps << name
          @step_dependencies[name] = []
        else
          # Filter out reserved dependency symbols :none and :nothing, and expand parallel group names
          @step_dependencies[name] = expand_dependencies(Array(depends_on).reject { |dep| [:none, :nothing].include?(dep) })
        end

        @steps << { name: name, callable: callable, type: :named }
      else
        # Unnamed step: step ->(result) { ... } or step { |result| ... }
        callable = name_or_callable || block
        raise ArgumentError, "Step must respond to #call" unless callable.respond_to?(:call)

        callable = apply_middleware(callable)
        @steps << { callable: callable, type: :unnamed }
      end

      self
    end

    # Defines a parallel execution block. Steps within this block will execute concurrently.
    # @param name [Symbol, nil] optional name for the parallel group
    # @param depends_on [Symbol, Array] dependencies for this parallel group
    # @param block [Block] block containing step definitions
    # @return [self]
    # @example Named parallel group with dependencies
    #   parallel :fetch_data, depends_on: :validate do
    #     step :fetch_orders, ->(result) { ... }
    #     step :fetch_products, ->(result) { ... }
    #   end
    #   step :process, ->(result) { ... }, depends_on: :fetch_data
    def parallel(name = nil, depends_on: :none, &block)
      # Validate name if provided
      if name && [:none, :nothing].include?(name)
        raise ArgumentError, "Parallel group name '#{name}' is reserved. Please use a different name."
      end

      # Filter and expand dependencies
      filtered_deps = expand_dependencies(Array(depends_on).reject { |dep| [:none, :nothing].include?(dep) })

      # Create and evaluate the parallel block
      group = ParallelBlock.new(self)
      group.instance_eval(&block)

      if name
        # Named parallel group - track it for dependency resolution
        step_names = group.steps.map { |s| s[:name] }.compact
        @parallel_groups[name] = {
          steps: step_names,
          dependencies: filtered_deps
        }

        # Add dependencies from the parallel group to its contained steps
        step_names.each do |step_name|
          @step_dependencies[step_name] = filtered_deps
        end
      end

      @steps << { steps: group.steps, type: :parallel, name: name }
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

    # Executes the pipeline with a given initial result. Each step is called in order, and the result of a step
    # is passed to the next. Execution can be short-circuited by a step returning an object that does not
    # satisfy a `continue?` condition.
    # @param result [Object] the initial data/input to be passed through the pipeline
    # @return [Object] the result of executing the pipeline
    def call(result)
      steps.reduce(result) do |res, step_def|
        return res if res.respond_to?(:continue?) && !res.continue?

        case step_def
        when Hash
          execute_step_def(step_def, res)
        else
          # Backward compatibility with old format
          step_def.call(res)
        end
      end
    end

    # Executes the pipeline with parallel execution where possible.
    # For named steps with dependencies, automatically detects which steps can run in parallel.
    # For explicit parallel blocks, executes them concurrently.
    # @param result [Object] the initial data/input to be passed through the pipeline
    # @param strategy [Symbol] :auto (automatic detection) or :explicit (only explicit parallel blocks)
    # @return [Object] the result of executing the pipeline
    def call_parallel(result, strategy: :auto)
      if strategy == :auto && has_named_steps?
        execute_with_dependency_graph(result)
      else
        execute_with_explicit_parallelism(result)
      end
    end

    # Check if async gem is available for parallel execution
    # @return [Boolean]
    def async_available?
      ParallelExecutor.async_available?
    end

    # Get the dependency graph for this pipeline
    # @return [DependencyGraph, nil] dependency graph if pipeline has named steps
    def dependency_graph
      return nil unless has_named_steps?
      DependencyGraph.new(@step_dependencies)
    end

    # Create a visualizer for this pipeline's dependency graph
    # @return [DependencyGraphVisualizer, nil] visualizer if pipeline has named steps
    def visualize
      graph = dependency_graph
      return nil unless graph
      DependencyGraphVisualizer.new(graph)
    end

    # Print ASCII visualization of the pipeline's dependency graph
    # @param show_groups [Boolean] whether to show parallel execution groups
    # @return [String, nil] ASCII visualization or nil if no named steps
    def visualize_ascii(show_groups: true)
      visualizer = visualize
      return nil unless visualizer
      visualizer.to_ascii(show_groups: show_groups)
    end

    # Export pipeline visualization to DOT format
    # @param include_groups [Boolean] whether to color-code parallel groups
    # @param orientation [String] graph orientation: 'TB' or 'LR'
    # @return [String, nil] DOT format or nil if no named steps
    def visualize_dot(include_groups: true, orientation: 'TB')
      visualizer = visualize
      return nil unless visualizer
      visualizer.to_dot(include_groups: include_groups, orientation: orientation)
    end

    # Export pipeline visualization to Mermaid format
    # @return [String, nil] Mermaid format or nil if no named steps
    def visualize_mermaid
      visualizer = visualize
      return nil unless visualizer
      visualizer.to_mermaid
    end

    # Get execution plan for this pipeline
    # @return [String, nil] execution plan or nil if no named steps
    def execution_plan
      visualizer = visualize
      return nil unless visualizer
      visualizer.to_execution_plan
    end

    private

    # Expands parallel group names in dependencies to all steps in those groups
    # @param deps [Array<Symbol>] array of dependency symbols
    # @return [Array<Symbol>] expanded array with parallel groups replaced by their steps
    def expand_dependencies(deps)
      deps.flat_map do |dep|
        if @parallel_groups.key?(dep)
          # This is a parallel group name - expand to all steps in the group
          @parallel_groups[dep][:steps]
        else
          # Regular step name
          dep
        end
      end
    end

    def validate_concurrency!
      valid_options = [:auto, :threads, :async]
      unless valid_options.include?(@concurrency)
        raise ArgumentError, "Invalid concurrency option: #{@concurrency.inspect}. Valid options: #{valid_options.inspect}"
      end

      if @concurrency == :async && !ParallelExecutor.async_available?
        raise ArgumentError, "Concurrency set to :async but async gem is not available. Install with: gem 'async', '~> 2.0'"
      end
    end

    def has_named_steps?
      @named_steps.any?
    end

    def execute_step_def(step_def, result)
      case step_def[:type]
      when :named, :unnamed
        step_def[:callable].call(result)
      when :parallel
        execute_parallel_group(step_def[:steps], result)
      end
    end

    def execute_parallel_group(steps, result)
      callables = steps.map { |s| s[:callable] }
      results = ParallelExecutor.execute_parallel(callables, result, concurrency: @concurrency)

      # Return the first halted result, or the last result if all continued
      results.find { |r| r.respond_to?(:continue?) && !r.continue? } || results.last
    end

    def execute_with_dependency_graph(result)
      require_relative 'dependency_graph'

      current_result = result
      executed_steps = Set.new
      activated_steps = Set.new

      loop do
        # Build active dependencies: all non-optional steps + activated optional steps
        active_dependencies = build_active_dependencies(activated_steps, executed_steps)

        # Find the next group of steps that can be executed
        next_group = find_next_executable_group(active_dependencies, executed_steps)
        break if next_group.empty?

        if next_group.size == 1
          # Single step, execute sequentially
          step_name = next_group.first
          current_result = @named_steps[step_name].call(current_result)
          executed_steps << step_name

          # Process any newly activated steps
          process_activations(current_result, step_name, activated_steps)

          return current_result if current_result.respond_to?(:continue?) && !current_result.continue?
        else
          # Multiple steps, execute in parallel
          callables = next_group.map { |name| @named_steps[name] }
          results = ParallelExecutor.execute_parallel(callables, current_result, concurrency: @concurrency)

          # Check if any step halted
          halted_result = results.find { |r| r.respond_to?(:continue?) && !r.continue? }
          return halted_result if halted_result

          # Mark all steps as executed
          next_group.each { |name| executed_steps << name }

          # Process activations from all results
          next_group.each_with_index do |name, idx|
            process_activations(results[idx], name, activated_steps)
          end

          # Merge contexts, errors, and activated_steps from all parallel results
          merged_context = {}
          merged_errors = {}
          merged_activated = []
          results.each do |r|
            merged_context.merge!(r.context) if r.respond_to?(:context)
            if r.respond_to?(:errors)
              r.errors.each do |key, messages|
                merged_errors[key] ||= []
                merged_errors[key].concat(messages)
              end
            end
            merged_activated.concat(r.activated_steps) if r.respond_to?(:activated_steps)
          end

          # Use the last result's value but with merged context/errors/activated_steps
          last_result = results.last
          current_result = Result.new(
            last_result.value,
            context: merged_context,
            errors: merged_errors,
            activated_steps: merged_activated.uniq
          )
        end
      end

      current_result
    end

    # Build the active step dependencies, excluding optional steps that haven't been activated
    def build_active_dependencies(activated_steps, executed_steps)
      active_deps = {}
      @step_dependencies.each do |step_name, deps|
        # Skip optional steps that haven't been activated
        next if @optional_steps.include?(step_name) && !activated_steps.include?(step_name)

        # Check if any dependency is an optional step that hasn't been activated
        has_unactivated_optional_dep = deps.any? do |dep|
          @optional_steps.include?(dep) && !activated_steps.include?(dep)
        end

        # If this step depends on an optional step that hasn't been activated, skip it
        # (it can only run if/when that optional dependency gets activated)
        next if has_unactivated_optional_dep

        # Filter dependencies to only include steps that will actually run
        # (non-optional steps and activated optional steps)
        filtered_deps = deps.select do |dep|
          !@optional_steps.include?(dep) || activated_steps.include?(dep)
        end

        active_deps[step_name] = filtered_deps
      end
      active_deps
    end

    # Find the next group of steps that can be executed
    def find_next_executable_group(active_dependencies, executed_steps)
      # Find steps whose dependencies have all been executed
      ready_steps = active_dependencies.keys.select do |step_name|
        next false if executed_steps.include?(step_name)

        deps = active_dependencies[step_name]
        deps.all? { |dep| executed_steps.include?(dep) }
      end

      ready_steps
    end

    # Process activated steps from a result, validating each
    def process_activations(result, current_step, activated_steps)
      return unless result.respond_to?(:activated_steps)

      result.activated_steps.each do |step_name|
        next if activated_steps.include?(step_name) # Idempotent

        unless @named_steps.key?(step_name)
          raise ArgumentError, "Step :#{current_step} attempted to activate unknown step :#{step_name}"
        end

        unless @optional_steps.include?(step_name)
          raise ArgumentError, "Step :#{current_step} attempted to activate non-optional step :#{step_name}. Only steps declared with depends_on: :optional can be activated."
        end

        activated_steps << step_name
      end
    end

    def execute_with_explicit_parallelism(result)
      steps.reduce(result) do |res, step_def|
        return res if res.respond_to?(:continue?) && !res.continue?
        execute_step_def(step_def, res)
      end
    end

    # Helper class for building parallel blocks
    class ParallelBlock
      attr_reader :steps

      def initialize(pipeline)
        @pipeline = pipeline
        @steps = []
      end

      def step(name_or_callable = nil, callable = nil, depends_on: [], &block)
        if name_or_callable.is_a?(Symbol)
          name = name_or_callable
          callable ||= block
          raise ArgumentError, "Step must respond to #call" unless callable.respond_to?(:call)
          callable = @pipeline.send(:apply_middleware, callable)
          # Register the step in the pipeline's named_steps
          @pipeline.instance_variable_get(:@named_steps)[name] = callable
          @steps << { name: name, callable: callable, type: :named }
        else
          callable = name_or_callable || block
          raise ArgumentError, "Step must respond to #call" unless callable.respond_to?(:call)
          callable = @pipeline.send(:apply_middleware, callable)
          @steps << { callable: callable, type: :unnamed }
        end
        self
      end
    end
  end
end


