require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class ThreadFallbackTest < Minitest::Test
    def test_threads_are_used_when_async_unavailable
      # Temporarily override ASYNC_AVAILABLE to test thread fallback
      original_async = Object.const_get('ASYNC_AVAILABLE')

      begin
        # Silence warnings about constant redefinition
        Object.send(:remove_const, 'ASYNC_AVAILABLE')
        Object.const_set('ASYNC_AVAILABLE', false)

        execution_order = []
        mutex = Mutex.new

        pipeline = Pipeline.new do
          parallel do
            step ->(result) {
              sleep 0.01  # Small delay to ensure concurrency
              mutex.synchronize { execution_order << :step_a }
              result.continue(result.value + 1)
            }
            step ->(result) {
              sleep 0.01  # Small delay to ensure concurrency
              mutex.synchronize { execution_order << :step_b }
              result.continue(result.value + 10)
            }
            step ->(result) {
              sleep 0.01  # Small delay to ensure concurrency
              mutex.synchronize { execution_order << :step_c }
              result.continue(result.value + 100)
            }
          end
        end

        start_time = Time.now
        result = pipeline.call(Result.new(0))
        duration = Time.now - start_time

        # Verify all steps executed
        assert_equal 3, execution_order.size
        assert_includes execution_order, :step_a
        assert_includes execution_order, :step_b
        assert_includes execution_order, :step_c

        # If truly parallel with threads, should complete in ~0.01s
        # If sequential, would take ~0.03s
        # Allow some margin for thread scheduling overhead
        assert duration < 0.025, "Expected parallel execution (~0.01s), but took #{duration}s"

      ensure
        # Restore original ASYNC_AVAILABLE
        Object.send(:remove_const, 'ASYNC_AVAILABLE')
        Object.const_set('ASYNC_AVAILABLE', original_async)
      end
    end

    def test_execute_with_threads_directly
      steps = [
        ->(result) { result.continue(result.value + 1) },
        ->(result) { result.continue(result.value + 10) },
        ->(result) { result.continue(result.value + 100) }
      ]

      results = ParallelExecutor.execute_with_threads(steps, Result.new(0))

      assert_equal 3, results.size
      assert_equal 1, results[0].value
      assert_equal 10, results[1].value
      assert_equal 100, results[2].value
    end
  end
end
