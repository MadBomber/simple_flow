# frozen_string_literal: true

require 'test_helper'

class ParallelPipelineTest < Minitest::Test
  def test_pipeline_with_parallel_block
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value + 1) }

      parallel do
        step ->(result) { result.with_context(:step1, "executed").continue(result.value) }
        step ->(result) { result.with_context(:step2, "executed").continue(result.value) }
      end

      step ->(result) { result.continue(result.value * 2) }
    end

    result = pipeline.call(SimpleFlow::Result.new(5))

    assert_equal 12, result.value # (5 + 1) * 2
    assert_equal "executed", result.context[:step1]
    assert_equal "executed", result.context[:step2]
  end

  def test_pipeline_with_multiple_parallel_blocks
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value + 1) }

      parallel do
        step ->(result) { result.with_context(:group1_step1, true).continue(result.value) }
        step ->(result) { result.with_context(:group1_step2, true).continue(result.value) }
      end

      step ->(result) { result.continue(result.value * 2) }

      parallel do
        step ->(result) { result.with_context(:group2_step1, true).continue(result.value) }
        step ->(result) { result.with_context(:group2_step2, true).continue(result.value) }
      end
    end

    result = pipeline.call(SimpleFlow::Result.new(5))

    assert_equal 12, result.value
    assert result.context[:group1_step1]
    assert result.context[:group1_step2]
    assert result.context[:group2_step1]
    assert result.context[:group2_step2]
  end

  def test_parallel_steps_halt_pipeline_if_any_fails
    pipeline = SimpleFlow::Pipeline.new do
      parallel do
        step ->(result) { result.continue("success") }
        step ->(result) { result.halt("failed").with_error(:validation, "Failed validation") }
      end

      step ->(result) { result.continue("should not execute") }
    end

    result = pipeline.call(SimpleFlow::Result.new("initial"))

    refute result.continue?
    assert_includes result.errors[:validation], "Failed validation"
    refute_equal "should not execute", result.value
  end

  def test_parallel_execution_with_middleware
    log = []

    logging_middleware = ->(callable) {
      ->(result) {
        log << "before"
        result = callable.call(result)
        log << "after"
        result
      }
    }

    pipeline = SimpleFlow::Pipeline.new do
      use_middleware logging_middleware

      parallel do
        step ->(result) { result.with_context(:a, 1).continue(result.value) }
        step ->(result) { result.with_context(:b, 2).continue(result.value) }
      end
    end

    result = pipeline.call(SimpleFlow::Result.new("test"))

    # Middleware should be applied to the parallel steps
    assert log.length >= 2
    assert_equal 1, result.context[:a]
    assert_equal 2, result.context[:b]
  end

  def test_empty_parallel_block
    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) { result.continue(result.value + 1) }
      parallel do
        # empty
      end
      step ->(result) { result.continue(result.value * 2) }
    end

    result = pipeline.call(SimpleFlow::Result.new(5))

    assert_equal 12, result.value # (5 + 1) * 2
  end

  def test_sequential_and_parallel_mixed
    execution_log = []

    pipeline = SimpleFlow::Pipeline.new do
      step ->(result) {
        execution_log << "seq1"
        result.continue(result.value)
      }

      parallel do
        step ->(result) {
          sleep 0.01
          execution_log << "par1"
          result.continue(result.value)
        }
        step ->(result) {
          sleep 0.01
          execution_log << "par2"
          result.continue(result.value)
        }
      end

      step ->(result) {
        execution_log << "seq2"
        result.continue(result.value)
      }
    end

    pipeline.call(SimpleFlow::Result.new("test"))

    # seq1 should be first, seq2 should be last
    assert_equal "seq1", execution_log.first
    assert_equal "seq2", execution_log.last
    # par1 and par2 should be in the middle (in any order)
    assert_includes execution_log, "par1"
    assert_includes execution_log, "par2"
  end
end
