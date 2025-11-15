require 'minitest/autorun'
require_relative '../lib/simple_flow/step_tracker'
require_relative '../lib/simple_flow/result'

module SimpleFlow
  class StepTrackerTest < Minitest::Test
    def setup
      @step = ->(result) { result.continue(result.value * 2) }
      @tracker = StepTracker.new(@step)
    end

    def test_tracks_successful_step
      result = Result.new(5)
      new_result = @tracker.call(result)

      assert_equal 10, new_result.value
      assert new_result.continue?
    end

    def test_tracks_halted_step
      halting_step = ->(result) { result.halt(result.value + 1) }
      tracker = StepTracker.new(halting_step)

      result = Result.new(10)
      new_result = tracker.call(result)

      refute new_result.continue?
      assert_equal 11, new_result.value
      assert_equal halting_step, new_result.context[:halted_step]
    end

    def test_does_not_track_continuing_step
      result = Result.new(3)
      new_result = @tracker.call(result)

      assert new_result.continue?
      assert_nil new_result.context[:halted_step]
    end

    def test_delegates_to_wrapped_step
      custom_step = ->(result) { result.continue("custom") }
      tracker = StepTracker.new(custom_step)

      result = Result.new("initial")
      new_result = tracker.call(result)

      assert_equal "custom", new_result.value
    end
  end
end
