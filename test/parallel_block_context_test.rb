# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  class ParallelBlockContextTest < Minitest::Test
    def setup
      @result = Result.new(0)
    end

    # 1: All context keys from parallel steps are merged
    def test_parallel_block_merges_contexts_via_call
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_context(:a, 1).continue(r.value) }
          step ->(r) { r.with_context(:b, 2).continue(r.value) }
          step ->(r) { r.with_context(:c, 3).continue(r.value) }
        end
      end

      result = pipeline.call(@result)

      assert_equal 1, result.context[:a]
      assert_equal 2, result.context[:b]
      assert_equal 3, result.context[:c]
    end

    # 1b: Same via call_parallel (explicit strategy)
    def test_parallel_block_merges_contexts_via_call_parallel
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_context(:x, :done).continue(r.value) }
          step ->(r) { r.with_context(:y, :done).continue(r.value) }
        end
      end

      result = pipeline.call_parallel(@result, strategy: :explicit)

      assert_equal :done, result.context[:x]
      assert_equal :done, result.context[:y]
    end

    # 1c: Sequential step after parallel block receives all merged context
    def test_sequential_step_after_parallel_receives_merged_context
      received_context = nil

      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_context(:p, 10).continue(r.value) }
          step ->(r) { r.with_context(:q, 20).continue(r.value) }
        end

        step ->(r) {
          received_context = r.context.dup
          r.continue(r.value)
        }
      end

      pipeline.call(@result)

      assert_equal 10, received_context[:p]
      assert_equal 20, received_context[:q]
    end

    # 2: Errors from all parallel steps are merged
    def test_parallel_block_merges_errors
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_error(:validation, "email invalid").continue(r.value) }
          step ->(r) { r.with_error(:auth, "not authorized").continue(r.value) }
        end
      end

      result = pipeline.call(@result)

      assert_equal ["email invalid"],  result.errors[:validation]
      assert_equal ["not authorized"], result.errors[:auth]
    end

    # 2b: Multiple errors on the same key are concatenated
    def test_parallel_block_concatenates_errors_on_same_key
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_error(:validation, "too short").continue(r.value) }
          step ->(r) { r.with_error(:validation, "invalid chars").continue(r.value) }
        end
      end

      result = pipeline.call(@result)

      assert_includes result.errors[:validation], "too short"
      assert_includes result.errors[:validation], "invalid chars"
    end

    # 3: A halted step causes the parallel group to halt
    def test_parallel_block_halt_short_circuits
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_context(:ok, true).continue(r.value) }
          step ->(r) { r.halt.with_error(:fatal, "step failed") }
        end

        step ->(r) { r.with_context(:after, true).continue(r.value) }
      end

      result = pipeline.call(@result)

      refute result.continue?
      assert_equal ["step failed"], result.errors[:fatal]
      assert_nil result.context[:after], "step after parallel should not have run"
    end

    # 4: Multiple parallel blocks each merge independently
    def test_multiple_parallel_blocks_each_merge
      pipeline = Pipeline.new do
        parallel do
          step ->(r) { r.with_context(:block1_a, :done).continue(r.value) }
          step ->(r) { r.with_context(:block1_b, :done).continue(r.value) }
        end

        parallel do
          step ->(r) { r.with_context(:block2_a, :done).continue(r.value) }
          step ->(r) { r.with_context(:block2_b, :done).continue(r.value) }
        end
      end

      result = pipeline.call(@result)

      assert_equal :done, result.context[:block1_a]
      assert_equal :done, result.context[:block1_b]
      assert_equal :done, result.context[:block2_a]
      assert_equal :done, result.context[:block2_b]
    end
  end
end
