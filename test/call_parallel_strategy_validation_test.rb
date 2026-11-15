# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # An unknown call_parallel strategy, such as a misspelled :explict, raises
  # instead of silently running as :explicit
  class CallParallelStrategyValidationTest < Minitest::Test
    def setup
      @result = Result.new(1)
    end

    def increment_pipeline
      Pipeline.new do
        step :increment, ->(r) { r.continue(r.value + 1) }, depends_on: :none
      end
    end

    def test_misspelled_strategy_raises_naming_value_and_allowed_ones
      error = assert_raises(ArgumentError) do
        increment_pipeline.call_parallel(@result, strategy: :explict)
      end

      assert_match(/:explict/, error.message)
      assert_match(/\[:auto, :explicit\]/, error.message)
    end

    def test_unknown_strategy_raises_before_any_step_runs
      ran = false
      pipeline = Pipeline.new do
        step lambda { |r|
          ran = true
          r.continue(r.value)
        }
      end

      assert_raises(ArgumentError) { pipeline.call_parallel(@result, strategy: :nope) }
      refute ran
    end

    def test_known_strategies_still_run
      %i[auto explicit].each do |strategy|
        assert_equal 2, increment_pipeline.call_parallel(@result, strategy: strategy).value
      end
    end

    def test_validator_in_isolation
      pipeline = increment_pipeline

      assert_nil pipeline.send(:validate_strategy!, :auto)
      assert_nil pipeline.send(:validate_strategy!, :explicit)
      assert_raises(ArgumentError) { pipeline.send(:validate_strategy!, :bogus) }
      assert_raises(ArgumentError) { pipeline.send(:validate_strategy!, 'auto') }
    end
  end
end
