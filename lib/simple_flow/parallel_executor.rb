# frozen_string_literal: true

begin
  require 'async'
  require 'async/barrier'
  ASYNC_AVAILABLE = true
rescue LoadError
  ASYNC_AVAILABLE = false
end

module SimpleFlow
  ##
  # ParallelExecutor handles parallel execution of steps.
  # Uses the async gem for fiber-based concurrency if available,
  # falls back to Ruby threads otherwise.
  #
  class ParallelExecutor
    # Execute a group of steps in parallel
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @param concurrency [Symbol] concurrency model (:auto, :threads, :async)
    # @return [Array<Result>] array of results from each step
    def self.execute_parallel(steps, result, concurrency: :auto)
      case concurrency
      when :auto
        # Auto-detect: use async if available, otherwise threads
        ASYNC_AVAILABLE ? execute_with_async(steps, result) : execute_with_threads(steps, result)
      when :threads
        execute_with_threads(steps, result)
      when :async
        raise ArgumentError, "Async gem not available" unless ASYNC_AVAILABLE
        execute_with_async(steps, result)
      else
        raise ArgumentError, "Invalid concurrency option: #{concurrency.inspect}"
      end
    end

    # Execute steps with async gem (fiber-based concurrency)
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @return [Array<Result>] array of results from each step
    def self.execute_with_async(steps, result)
      results = []

      Async do
        barrier = Async::Barrier.new
        tasks = []

        steps.each do |step|
          tasks << barrier.async do
            step.call(result)
          end
        end

        barrier.wait
        results = tasks.map(&:result)
      end

      results
    end

    # Execute steps with Ruby threads (fallback for true parallelism)
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @return [Array<Result>] array of results from each step
    def self.execute_with_threads(steps, result)
      threads = steps.map do |step|
        Thread.new { step.call(result) }
      end

      threads.map(&:value)
    end

    # Check if async is available
    # @return [Boolean]
    def self.async_available?
      ASYNC_AVAILABLE
    end
  end
end
