# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # A parallel block keeps the activated steps of the incoming result and of
  # each branch (issue #34)
  class ParallelBlockActivationTest < Minitest::Test
    PASS = ->(r) { r.continue(r.value) }

    def build_pipeline
      Pipeline.new do
        step ->(r) { r.activate(:x) }
        parallel do
          step PASS
          step ->(r) { r.activate(:y) }
        end
      end
    end

    def test_call_keeps_incoming_and_branch_activations
      result = build_pipeline.call(Result.new(1))

      assert_equal %i[x y], result.activated_steps
    end

    def test_explicit_strategy_keeps_incoming_and_branch_activations
      result = build_pipeline.call_parallel(Result.new(1), strategy: :explicit)

      assert_equal %i[x y], result.activated_steps
    end

    def test_merge_parallel_activations_lists_each_step_once
      input    = Result.new(1).activate(:x)
      branches = [input.activate(:y), input.activate(:y, :z)]

      merged = Pipeline.new.send(:merge_parallel_activations, input, branches)

      assert_equal %i[x y z], merged
    end

    def test_merge_parallel_activations_ignores_plain_values
      assert_empty Pipeline.new.send(:merge_parallel_activations, 1, [2, 3])
    end
  end
end
