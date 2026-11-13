# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # The async backend hands a step's exception to the caller and works
  # inside a reactor that is already running (issue #30)
  class AsyncBackendTest < Minitest::Test
    # A step that yields to the reactor, then records +key+ in the context
    def self.pause(key)
      lambda do |r|
        sleep 0.01
        r.with_context(key, true).continue(r.value)
      end
    end

    def setup
      skip 'Async gem not available' unless ParallelExecutor.async_available?
    end

    def test_call_parallel_raises_the_step_exception
      pipeline = Pipeline.new(concurrency: :async) do
        step :a, ->(_r) { raise 'boom' }, depends_on: :none
        step :b, AsyncBackendTest.pause(:b), depends_on: :none
      end

      error = assert_raises(RuntimeError) { pipeline.call_parallel(Result.new(1)) }

      assert_equal 'boom', error.message
    end

    def test_parallel_block_raises_the_step_exception
      pipeline = Pipeline.new(concurrency: :async) do
        parallel do
          step AsyncBackendTest.pause(:a)
          step ->(_r) { raise 'boom' }
        end
      end

      error = assert_raises(RuntimeError) { pipeline.call(Result.new(1)) }

      assert_equal 'boom', error.message
    end

    def test_call_parallel_inside_a_running_reactor
      pipeline = Pipeline.new(concurrency: :async) do
        step :a, AsyncBackendTest.pause(:a), depends_on: :none
        step :b, AsyncBackendTest.pause(:b), depends_on: :none
      end

      result = Sync { pipeline.call_parallel(Result.new(1)) }

      assert_equal({ a: true, b: true }, result.context)
    end

    def test_capture_outcome_returns_the_step_result
      outcome = ParallelExecutor.capture_outcome(->(r) { r.continue(2) }, Result.new(1))

      assert_equal 2, outcome.first.value
      assert_nil outcome.last
    end

    def test_capture_outcome_returns_the_error_a_step_raised
      value, error = ParallelExecutor.capture_outcome(->(_r) { raise ArgumentError, 'bad' }, Result.new(1))

      assert_nil value
      assert_instance_of ArgumentError, error
      assert_equal 'bad', error.message
    end

    def test_execute_with_async_returns_results_in_step_order
      steps = [
        lambda do |r|
          sleep 0.02
          r.continue(:slow)
        end,
        ->(r) { r.continue(:fast) }
      ]

      results = ParallelExecutor.execute_with_async(steps, Result.new(nil))

      assert_equal %i[slow fast], results.map(&:value)
    end
  end
end
