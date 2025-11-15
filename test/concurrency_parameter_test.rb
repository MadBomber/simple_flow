require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class ConcurrencyParameterTest < Minitest::Test
    def test_default_concurrency_is_auto
      pipeline = Pipeline.new do
        step ->(result) { result.continue(result.value) }
      end

      assert_equal :auto, pipeline.concurrency
    end

    def test_explicit_threads_concurrency
      pipeline = Pipeline.new(concurrency: :threads) do
        parallel do
          step ->(result) { result.continue(result.value + 1) }
          step ->(result) { result.continue(result.value + 10) }
        end
      end

      assert_equal :threads, pipeline.concurrency

      result = pipeline.call(Result.new(0))
      assert result.continue?
    end

    def test_explicit_async_concurrency_with_async_available
      skip "Async gem not available" unless ParallelExecutor.async_available?

      pipeline = Pipeline.new(concurrency: :async) do
        parallel do
          step ->(result) { result.continue(result.value + 1) }
          step ->(result) { result.continue(result.value + 10) }
        end
      end

      assert_equal :async, pipeline.concurrency

      result = pipeline.call(Result.new(0))
      assert result.continue?
    end

    def test_error_when_requesting_async_without_gem
      skip "Async gem is available" if ParallelExecutor.async_available?

      error = assert_raises(ArgumentError) do
        Pipeline.new(concurrency: :async) do
          step ->(result) { result.continue(result.value) }
        end
      end

      assert_includes error.message, "async gem is not available"
    end

    def test_error_for_invalid_concurrency_option
      error = assert_raises(ArgumentError) do
        Pipeline.new(concurrency: :invalid) do
          step ->(result) { result.continue(result.value) }
        end
      end

      assert_includes error.message, "Invalid concurrency option"
      assert_includes error.message, ":invalid"
    end

    def test_threads_concurrency_forces_thread_execution
      pipeline = Pipeline.new(concurrency: :threads) do
        step :validate, ->(result) { result.continue(result.value + 1) }, depends_on: []
        step :fetch_a, ->(result) {
          result.with_context(:a, result.value + 10).continue(result.value)
        }, depends_on: [:validate]
        step :fetch_b, ->(result) {
          result.with_context(:b, result.value + 100).continue(result.value)
        }, depends_on: [:validate]
      end

      # Even if async is available, should use threads
      result = pipeline.call_parallel(Result.new(0))
      assert result.continue?
      # Both parallel steps should have executed and added their context
      assert_equal 11, result.context[:a]
      assert_equal 101, result.context[:b]
    end

    def test_auto_concurrency_with_named_steps
      pipeline = Pipeline.new(concurrency: :auto) do
        step :validate, ->(result) { result.continue(result.value + 1) }, depends_on: []
        step :fetch_a, ->(result) {
          result.with_context(:a, result.value + 10).continue(result.value)
        }, depends_on: [:validate]
        step :fetch_b, ->(result) {
          result.with_context(:b, result.value + 100).continue(result.value)
        }, depends_on: [:validate]
      end

      result = pipeline.call_parallel(Result.new(0))
      assert result.continue?
      # Both parallel steps should have executed and added their context
      assert_equal 11, result.context[:a]
      assert_equal 101, result.context[:b]
    end

    def test_concurrency_setting_persists_across_calls
      pipeline = Pipeline.new(concurrency: :threads) do
        parallel do
          step ->(result) { result.continue(result.value + 1) }
          step ->(result) { result.continue(result.value + 10) }
        end
      end

      # First call
      result1 = pipeline.call(Result.new(0))
      assert result1.continue?

      # Second call - should still use threads
      result2 = pipeline.call(Result.new(5))
      assert result2.continue?

      # Concurrency setting should be unchanged
      assert_equal :threads, pipeline.concurrency
    end

    def test_parallel_executor_respects_concurrency_parameter
      steps = [
        ->(result) { result.continue(result.value + 1) },
        ->(result) { result.continue(result.value + 10) }
      ]

      # Test with threads
      results = ParallelExecutor.execute_parallel(steps, Result.new(0), concurrency: :threads)
      assert_equal 2, results.size
      assert_equal 1, results[0].value
      assert_equal 10, results[1].value

      # Test with auto
      results = ParallelExecutor.execute_parallel(steps, Result.new(0), concurrency: :auto)
      assert_equal 2, results.size
      assert_equal 1, results[0].value
      assert_equal 10, results[1].value
    end

    def test_parallel_executor_error_for_invalid_concurrency
      steps = [
        ->(result) { result.continue(result.value + 1) }
      ]

      error = assert_raises(ArgumentError) do
        ParallelExecutor.execute_parallel(steps, Result.new(0), concurrency: :invalid)
      end

      assert_includes error.message, "Invalid concurrency option"
    end

    def test_parallel_executor_async_error_when_unavailable
      skip "Async gem is available" if ParallelExecutor.async_available?

      steps = [
        ->(result) { result.continue(result.value + 1) }
      ]

      error = assert_raises(ArgumentError) do
        ParallelExecutor.execute_parallel(steps, Result.new(0), concurrency: :async)
      end

      assert_includes error.message, "Async gem not available"
    end
  end
end
