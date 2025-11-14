# frozen_string_literal: true

require 'async'

module SimpleFlow
  ##
  # ParallelStep executes multiple steps concurrently using the Async gem.
  # All steps receive the same input result and their outputs are merged.
  #
  # This is useful when you have independent operations that can run in parallel,
  # such as fetching data from multiple sources or performing independent validations.
  #
  # Example:
  #   parallel = ParallelStep.new([step1, step2, step3])
  #   result = parallel.call(input_result)
  #
  class ParallelStep
    attr_reader :steps

    # Initializes a new ParallelStep with multiple steps to execute concurrently.
    # @param steps [Array<#call>] An array of callable objects (steps) to execute in parallel
    def initialize(steps = [])
      @steps = steps
    end

    # Adds a step to be executed in parallel.
    # @param callable [#call] A callable object to add to the parallel execution
    # @return [self] Returns self for method chaining
    def add_step(callable)
      @steps << callable
      self
    end

    # Executes all steps concurrently and merges their results.
    # Each step receives a copy of the input result and runs in its own fiber.
    # The results are merged by combining values, contexts, and errors.
    #
    # @param result [Result] The input result to pass to all parallel steps
    # @return [Result] A merged result containing combined outputs from all steps
    def call(result)
      return result if @steps.empty?

      # Execute all steps concurrently
      results = Async do
        @steps.map do |step|
          Async do
            step.call(result)
          end
        end.map(&:wait)
      end.wait

      # Merge all results
      merge_results(results, result)
    end

    private

    # Merges multiple results into a single result.
    # - Uses the value from the last non-halted result, or the last result if all are halted
    # - Merges all contexts together
    # - Merges all errors together
    # - If any result is halted, the merged result is halted
    #
    # @param results [Array<Result>] Array of results to merge
    # @param original [Result] The original input result (used as fallback)
    # @return [Result] The merged result
    def merge_results(results, original)
      return original if results.empty?

      # Find the last continuing result, or use the last result
      final_value = results.reverse.find { |r| r.continue? }&.value || results.last.value

      # Merge all contexts
      merged_context = results.reduce({}) { |acc, r| acc.merge(r.context) }

      # Merge all errors
      merged_errors = results.reduce({}) do |acc, r|
        r.errors.each do |key, messages|
          acc[key] ||= []
          acc[key].concat(messages)
        end
        acc
      end

      # Check if any result halted
      any_halted = results.any? { |r| !r.continue? }

      # Create the merged result
      merged = Result.new(
        final_value,
        context: merged_context,
        errors: merged_errors,
        continue: !any_halted
      )

      # If any step halted, halt the merged result
      any_halted ? merged.halt(merged.value) : merged
    end
  end
end
