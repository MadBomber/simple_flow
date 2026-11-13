# frozen_string_literal: true

require_relative 'test_helper'

module SimpleFlow
  # The threads backend waits for every step before raising, like async (#37)
  class ThreadsBackendWaitsTest < Minitest::Test
    def run_threads(steps)
      ParallelExecutor.execute_parallel(steps, Result.new(0), concurrency: :threads)
    end

    def test_siblings_finish_before_the_error_is_raised
      done   = Queue.new
      failed = Queue.new
      steps  = [
        lambda do |_|
          failed << true
          raise 'boom'
        end,
        lambda do |result|
          failed.pop
          # Nothing pushes to this queue; the timeout only gives a backend that
          # raises early time to do so while this step is still running
          Queue.new.pop(timeout: 0.2)
          done << :sibling
          result.continue(1)
        end
      ]

      error = assert_raises(RuntimeError) { run_threads(steps) }

      assert_equal 'boom', error.message
      assert_equal 1, done.size, 'sibling step was still running when the error was raised'
    end

    def test_raises_the_first_failing_step_in_step_order
      second_failed = Queue.new
      steps = [
        lambda do |_|
          second_failed.pop
          raise 'first'
        end,
        lambda do |_|
          second_failed << true
          raise 'second'
        end
      ]

      error = assert_raises(RuntimeError) { run_threads(steps) }

      assert_equal 'first', error.message
    end

    def test_a_failing_step_prints_nothing_to_stderr
      steps = [->(_) { raise 'boom' }]

      _, err = capture_io do
        assert_raises(RuntimeError) { run_threads(steps) }
      end

      assert_empty err
    end

    def test_returns_each_steps_result_in_order_when_none_fail
      steps = [->(r) { r.continue(1) }, ->(r) { r.continue(2) }]

      assert_equal [1, 2], run_threads(steps).map(&:value)
    end
  end
end
