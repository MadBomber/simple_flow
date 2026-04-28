# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class MaxConcurrentTest < Minitest::Test
    def setup
      @initial_result = Result.new(0)
    end

    # 1: Default nil — unlimited, no behavioral regression
    def test_default_nil_all_steps_complete
      skip "Async gem not available" unless ParallelExecutor.async_available?

      steps = 10.times.map { |i| ->(result) { result.continue(i) } }

      results = ParallelExecutor.execute_parallel(steps, @initial_result, concurrency: :async)

      assert_equal 10, results.size
      assert results.all?(&:continue?)
    end

    # 2: Cap enforced — peak concurrent fibers <= max_concurrent
    def test_cap_enforced_limits_peak_concurrency
      skip "Async gem not available" unless ParallelExecutor.async_available?

      max = 3
      mutex = Mutex.new
      concurrent = 0
      peak = 0

      steps = 10.times.map do
        ->(result) {
          mutex.synchronize { concurrent += 1; peak = [peak, concurrent].max }
          sleep 0.01
          mutex.synchronize { concurrent -= 1 }
          result.continue(result.value)
        }
      end

      ParallelExecutor.execute_parallel(steps, @initial_result, concurrency: :async, max_concurrent: max)

      assert_operator peak, :<=, max
    end

    # 3: Cap of 1 — never more than one concurrent fiber
    def test_cap_of_1_limits_peak_to_1
      skip "Async gem not available" unless ParallelExecutor.async_available?

      mutex = Mutex.new
      concurrent = 0
      peak = 0

      steps = 5.times.map do
        ->(result) {
          mutex.synchronize { concurrent += 1; peak = [peak, concurrent].max }
          sleep 0.005
          mutex.synchronize { concurrent -= 1 }
          result.continue(result.value)
        }
      end

      ParallelExecutor.execute_parallel(steps, @initial_result, concurrency: :async, max_concurrent: 1)

      assert_equal 1, peak
    end

    # 4: Thread fallback silently ignores max_concurrent — no error, all steps complete
    def test_thread_fallback_ignores_max_concurrent
      steps = 5.times.map { |i| ->(result) { result.continue(i) } }

      results = ParallelExecutor.execute_parallel(
        steps, @initial_result, concurrency: :threads, max_concurrent: 2
      )

      assert_equal 5, results.size
      assert results.all?(&:continue?)
    end

    # 5: call_parallel forwards max_concurrent through the dependency-graph path
    def test_call_parallel_forwards_max_concurrent_through_dependency_graph
      skip "Async gem not available" unless ParallelExecutor.async_available?

      max = 2
      mutex = Mutex.new
      concurrent = 0
      peak = 0

      make_tracked_step = ->(ctx_key) {
        ->(result) {
          mutex.synchronize { concurrent += 1; peak = [peak, concurrent].max }
          sleep 0.01
          mutex.synchronize { concurrent -= 1 }
          result.with_context(ctx_key, true).continue(result.value)
        }
      }

      pipeline = Pipeline.new(concurrency: :async) do
        step :validate, ->(result) { result.continue(result.value + 1) }, depends_on: []
        step :fetch_a,  make_tracked_step.call(:a), depends_on: [:validate]
        step :fetch_b,  make_tracked_step.call(:b), depends_on: [:validate]
        step :fetch_c,  make_tracked_step.call(:c), depends_on: [:validate]
        step :merge,    ->(result) { result.continue(result.value) }, depends_on: [:fetch_a, :fetch_b, :fetch_c]
      end

      result = pipeline.call_parallel(@initial_result, max_concurrent: max)

      assert result.continue?
      assert_operator peak, :<=, max
    end

    # 6: Explicit parallel blocks forward max_concurrent
    def test_call_parallel_forwards_max_concurrent_through_explicit_parallel_blocks
      skip "Async gem not available" unless ParallelExecutor.async_available?

      max = 2
      mutex = Mutex.new
      concurrent = 0
      peak = 0

      make_tracked_step = -> {
        ->(result) {
          mutex.synchronize { concurrent += 1; peak = [peak, concurrent].max }
          sleep 0.01
          mutex.synchronize { concurrent -= 1 }
          result.continue(result.value)
        }
      }

      pipeline = Pipeline.new(concurrency: :async) do
        parallel do
          step make_tracked_step.call
          step make_tracked_step.call
          step make_tracked_step.call
          step make_tracked_step.call
        end
      end

      pipeline.call_parallel(@initial_result, max_concurrent: max)

      assert_operator peak, :<=, max
    end
  end
end
