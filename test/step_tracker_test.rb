# frozen_string_literal: true

require 'test_helper'

module SimpleFlow
  class StepTrackerTest < Minitest::Test
    def test_call_passes_through_when_continue_is_true
      step = ->(result) { result.continue(result.value + 1) }
      tracked_step = StepTracker.new(step)

      result = tracked_step.call(Result.new(5))

      assert_equal 6, result.value
      assert result.continue?
      assert_nil result.context[:halted_step]
    end

    def test_call_adds_halted_step_context_when_halted
      step = ->(result) { result.halt(result.value) }
      tracked_step = StepTracker.new(step)

      result = tracked_step.call(Result.new(10))

      assert_equal 10, result.value
      refute result.continue?
      assert_equal step, result.context[:halted_step]
    end

    def test_delegates_to_wrapped_object
      step = ->(result) { result.continue("processed") }
      tracked_step = StepTracker.new(step)

      assert tracked_step.respond_to?(:call)
      assert_equal step, tracked_step.__getobj__
    end
  end
end
