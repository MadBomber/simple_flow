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
  #   step :fetch_user, ->(result) { ... }, depends_on: []
  #   step :fetch_orders, ->(result) { ... }, depends_on: [:fetch_user]
  #   step :fetch_products, ->(result) { ... }, depends_on: [:fetch_user]
  #   step :calculate, ->(result) { ... }, depends_on: [:fetch_orders, :fetch_products]
  # end
  #
  # result = pipeline.call_parallel(initial_data)  # Auto-detects parallelism
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
    attr_reader :steps, :middlewares, :named_steps, :step_dependencies

    # Initializes a new Pipeline object. A block can be provided to dynamically configure the pipeline,
    # allowing the addition of steps and middleware.
    def initialize(&config)
      @steps = []
      @middlewares = []
      @named_steps = {}
      @step_dependencies = {}
      @parallel_groups = []
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
        raise ArgumentError, "Step must respond to #call" unless callable.respond_to?(:call)

        callable = apply_middleware(callable)
        @named_steps[name] = callable
        @step_dependencies[name] = Array(depends_on)
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
    # @param block [Block] block containing step definitions
    # @return [self]
    def parallel(&block)
      group = ParallelBlock.new(self)
      group.instance_eval(&block)
      @steps << { steps: group.steps, type: :parallel }
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

    private

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
      results = ParallelExecutor.execute_parallel(callables, result)

      # Return the first halted result, or the last result if all continued
      results.find { |r| r.respond_to?(:continue?) && !r.continue? } || results.last
    end

    def execute_with_dependency_graph(result)
      require_relative 'dependency_graph'

      graph = DependencyGraph.new(@step_dependencies)
      parallel_groups = graph.parallel_order

      current_result = result
      step_results = {}

      parallel_groups.each do |group|
        if group.size == 1
          # Single step, execute sequentially
          step_name = group.first
          current_result = @named_steps[step_name].call(current_result)
          step_results[step_name] = current_result
          return current_result if current_result.respond_to?(:continue?) && !current_result.continue?
        else
          # Multiple steps, execute in parallel
          callables = group.map { |name| @named_steps[name] }
          results = ParallelExecutor.execute_parallel(callables, current_result)

          # Check if any step halted
          halted_result = results.find { |r| r.respond_to?(:continue?) && !r.continue? }
          return halted_result if halted_result

          # Merge contexts and errors from all parallel results
          merged_context = {}
          merged_errors = {}
          results.each do |r|
            merged_context.merge!(r.context) if r.respond_to?(:context)
            if r.respond_to?(:errors)
              r.errors.each do |key, messages|
                merged_errors[key] ||= []
                merged_errors[key].concat(messages)
              end
            end
          end

          # Store results and create merged result
          group.each_with_index do |name, idx|
            step_results[name] = results[idx]
          end

          # Use the last result's value but with merged context/errors
          last_result = results.last
          current_result = Result.new(
            last_result.value,
            context: merged_context,
            errors: merged_errors
          )
        end
      end

      current_result
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


