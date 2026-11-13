# frozen_string_literal: true

begin
  require 'async'
  require 'async/barrier'
  require 'async/semaphore'
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
    # @param max_concurrent [Integer, nil] most steps to run at once (async only); nil means no cap
    # @return [Array<Result>] array of results from each step
    # @raise [ArgumentError] if max_concurrent is not a positive Integer or nil
    def self.execute_parallel(steps, result, concurrency: :auto, max_concurrent: nil)
      validate_max_concurrent(max_concurrent)

      case concurrency
      when :auto
        ASYNC_AVAILABLE ? execute_with_async(steps, result, max_concurrent: max_concurrent)
                        : execute_with_threads(steps, result)
      when :threads
        execute_with_threads(steps, result)
      when :async
        raise ArgumentError, "Async gem not available" unless ASYNC_AVAILABLE
        execute_with_async(steps, result, max_concurrent: max_concurrent)
      else
        raise ArgumentError, "Invalid concurrency option: #{concurrency.inspect}"
      end
    end

    # Async::Semaphore.new(0) never lets a task start, so a cap below 1
    # would hang forever rather than fail
    # @param max_concurrent [Object] the caller's max_concurrent
    # @raise [ArgumentError] unless it is a positive Integer or nil
    def self.validate_max_concurrent(max_concurrent)
      return if max_concurrent.nil? || (max_concurrent.is_a?(Integer) && max_concurrent.positive?)

      raise ArgumentError, "max_concurrent must be a positive Integer or nil, got #{max_concurrent.inspect}"
    end

    # Execute steps with async gem (fiber-based concurrency)
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @return [Array<Result>] array of results from each step
    def self.execute_with_async(steps, result, max_concurrent: nil)
      # Sync (not Async) waits for the block, lets a step's exception reach the
      # caller and reuses a reactor that is already running
      outcomes = Sync do
        semaphore = max_concurrent ? Async::Semaphore.new(max_concurrent) : nil
        barrier   = Async::Barrier.new(parent: semaphore)

        begin
          steps.map { |step| barrier.async { capture_outcome(step, result) } }.map(&:wait)
        ensure
          barrier.stop
        end
      end

      error = outcomes.filter_map(&:last).first
      raise error if error

      outcomes.map(&:first)
    end

    # Calls a step and returns what it produced or the error it raised, so a
    # failure is raised once by the caller rather than logged by the task
    # @param step [#call] the step to run
    # @param result [Result] the input result
    # @return [Array(Object, StandardError)] [step result, nil] or [nil, error]
    def self.capture_outcome(step, result)
      [step.call(result), nil]
    rescue StandardError => e
      [nil, e]
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
