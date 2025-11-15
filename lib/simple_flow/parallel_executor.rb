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
  # ParallelExecutor handles parallel execution of steps using the async gem.
  # Falls back to sequential execution if async gem is not available.
  #
  class ParallelExecutor
    # Execute a group of steps in parallel
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @return [Array<Result>] array of results from each step
    def self.execute_parallel(steps, result)
      return execute_sequential(steps, result) unless ASYNC_AVAILABLE

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

    # Execute steps sequentially (fallback)
    # @param steps [Array<Proc>] array of callable steps
    # @param result [Result] the input result
    # @return [Array<Result>] array of results from each step
    def self.execute_sequential(steps, result)
      steps.map { |step| step.call(result) }
    end

    # Check if async is available
    # @return [Boolean]
    def self.async_available?
      ASYNC_AVAILABLE
    end
  end
end
