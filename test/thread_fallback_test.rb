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

        # Each step waits until every step has started, which only happens when
        # they run at the same time. Run one after another, every step but the
        # last times out and records false.
        increments = [1, 10, 100]
        arrivals   = 0
        mutex      = Mutex.new
        go         = Queue.new
        seen       = Queue.new

        pipeline = Pipeline.new do
          parallel do
            increments.each do |increment|
              step(lambda do |result|
                last = mutex.synchronize { (arrivals += 1) == increments.size }
                increments.size.times { go << true } if last
                seen << [increment, Thread.current, go.pop(timeout: 5) || false]
                result.continue(result.value + increment)
              end)
            end
          end
        end

        result = pipeline.call(Result.new(0))
        runs = Array.new(seen.size) { seen.pop }
        ran, threads, released = runs.transpose

        assert_equal increments.size, runs.size, 'Expected one run per step'
        assert_equal 100, result.value
        assert_equal increments, ran.sort, 'Expected every step to run once'
        assert_equal increments.size, threads.uniq.size, 'Expected each step on its own thread'
        refute_includes threads, Thread.current, 'Expected no step on the calling thread'
        assert_equal [true] * increments.size, released, 'Expected all steps to run concurrently'
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
