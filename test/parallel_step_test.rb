# frozen_string_literal: true

require 'test_helper'

module SimpleFlow
  class ParallelStepTest < Minitest::Test
    def test_parallel_step_with_no_steps
      parallel_step = ParallelStep.new
      result = parallel_step.call(Result.new("input"))

      assert_equal "input", result.value
      assert result.continue?
    end

    def test_parallel_step_executes_all_steps
      execution_order = []

      step1 = ->(result) {
        sleep 0.01
        execution_order << 1
        result.continue(result.value)
      }

      step2 = ->(result) {
        sleep 0.01
        execution_order << 2
        result.continue(result.value)
      }

      step3 = ->(result) {
        sleep 0.01
        execution_order << 3
        result.continue(result.value)
      }

      parallel_step = ParallelStep.new([step1, step2, step3])
      result = parallel_step.call(Result.new("test"))

      assert_equal 3, execution_order.length
      assert_equal "test", result.value
    end

    def test_parallel_step_merges_contexts
      step1 = ->(result) {
        result.with_context(:user_id, 123).continue(result.value)
      }

      step2 = ->(result) {
        result.with_context(:order_id, 456).continue(result.value)
      }

      parallel_step = ParallelStep.new([step1, step2])
      result = parallel_step.call(Result.new("data"))

      assert_equal 123, result.context[:user_id]
      assert_equal 456, result.context[:order_id]
    end

    def test_parallel_step_merges_errors
      step1 = ->(result) {
        result.with_error(:validation, "Error 1").continue(result.value)
      }

      step2 = ->(result) {
        result.with_error(:validation, "Error 2").continue(result.value)
      }

      parallel_step = ParallelStep.new([step1, step2])
      result = parallel_step.call(Result.new("data"))

      assert_includes result.errors[:validation], "Error 1"
      assert_includes result.errors[:validation], "Error 2"
      assert_equal 2, result.errors[:validation].length
    end

    def test_parallel_step_halts_if_any_step_halts
      step1 = ->(result) {
        result.continue("success")
      }

      step2 = ->(result) {
        result.halt("failed")
      }

      parallel_step = ParallelStep.new([step1, step2])
      result = parallel_step.call(Result.new("data"))

      refute result.continue?
    end

    def test_add_step
      parallel_step = ParallelStep.new
      step1 = ->(result) { result.continue("test") }

      parallel_step.add_step(step1)

      assert_equal 1, parallel_step.steps.length
      assert_equal step1, parallel_step.steps.first
    end

    def test_parallel_execution_is_faster_than_sequential
      step1 = ->(result) {
        sleep 0.05
        result.continue(result.value)
      }

      step2 = ->(result) {
        sleep 0.05
        result.continue(result.value)
      }

      step3 = ->(result) {
        sleep 0.05
        result.continue(result.value)
      }

      parallel_step = ParallelStep.new([step1, step2, step3])

      start_time = Time.now
      parallel_step.call(Result.new("test"))
      parallel_duration = Time.now - start_time

      # Parallel should be faster than 0.15s (3 * 0.05s sequential)
      # but allow some overhead for fiber management
      assert parallel_duration < 0.12, "Parallel execution should be faster than sequential"
    end
  end
end
