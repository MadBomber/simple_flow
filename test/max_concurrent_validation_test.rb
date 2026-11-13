# frozen_string_literal: true

require 'minitest/autorun'
require 'timeout'
require_relative '../lib/simple_flow'

module SimpleFlow
  # A max_concurrent that is not a positive Integer or nil raises instead of
  # hanging forever on the async backend
  class MaxConcurrentValidationTest < Minitest::Test
    def setup
      @result = Result.new(0)
    end

    def two_step_pipeline(concurrency: :auto)
      Pipeline.new(concurrency: concurrency) do
        step :a, ->(r) { r.with_context(:a, true).continue(r.value) }
        step :b, ->(r) { r.with_context(:b, true).continue(r.value) }
      end
    end

    def call_with(max_concurrent, concurrency: :auto)
      Timeout.timeout(2) do
        two_step_pipeline(concurrency: concurrency).call_parallel(@result, max_concurrent: max_concurrent)
      end
    end

    def test_zero_raises
      error = assert_raises(ArgumentError) { call_with(0) }
      assert_match(/max_concurrent must be a positive Integer or nil, got 0/, error.message)
    end

    def test_negative_raises
      assert_raises(ArgumentError) { call_with(-1) }
    end

    def test_string_raises
      error = assert_raises(ArgumentError) { call_with('2') }
      assert_match(/got "2"/, error.message)
    end

    def test_zero_raises_with_threads
      assert_raises(ArgumentError) { call_with(0, concurrency: :threads) }
    end

    def test_zero_raises_in_explicit_parallel_block
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.continue(r.value) }
          step ->(r) { r.continue(r.value) }
        end
      end

      assert_raises(ArgumentError) do
        Timeout.timeout(2) { pipeline.call_parallel(@result, max_concurrent: 0) }
      end
    end

    def test_zero_raises_from_executor
      steps = [->(r) { r }, ->(r) { r }]

      assert_raises(ArgumentError) do
        Timeout.timeout(2) { ParallelExecutor.execute_parallel(steps, @result, max_concurrent: 0) }
      end
    end

    def test_nil_and_positive_integer_still_run
      [nil, 2].each do |max_concurrent|
        final = call_with(max_concurrent)

        assert_equal({ a: true, b: true }, final.context)
      end
    end
  end
end
