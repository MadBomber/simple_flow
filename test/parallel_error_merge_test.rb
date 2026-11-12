# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # Errors already on the result entering a parallel group are reported once,
  # not once per branch (issue #18)
  class ParallelErrorMergeTest < Minitest::Test
    VALIDATE = ->(r) { r.with_error(:input, 'name missing').continue(r.value) }
    PASS     = ->(r) { r.continue(r.value) }
    TOO_LONG = ->(r) { r.with_error(:input, 'name too long').continue(r.value) }

    def test_call_parallel_keeps_inherited_errors_once
      pipeline = Pipeline.new do
        step :validate, VALIDATE
        step :a, PASS, depends_on: [:validate]
        step :b, PASS, depends_on: [:validate]
      end

      result = pipeline.call_parallel(Result.new(1))

      assert_equal({ input: ['name missing'] }, result.errors)
    end

    def test_parallel_block_keeps_inherited_errors_once
      pipeline = Pipeline.new do
        step VALIDATE
        parallel do
          step PASS
          step PASS
        end
      end

      result = pipeline.call(Result.new(1))

      assert_equal({ input: ['name missing'] }, result.errors)
    end

    def test_call_parallel_keeps_branch_error_on_existing_key_once
      pipeline = Pipeline.new do
        step :validate, VALIDATE
        step :a, TOO_LONG, depends_on: [:validate]
        step :b, PASS, depends_on: [:validate]
      end

      result = pipeline.call_parallel(Result.new(1))

      assert_equal({ input: ['name missing', 'name too long'] }, result.errors)
    end

    def test_parallel_block_keeps_branch_error_on_existing_key_once
      pipeline = Pipeline.new do
        step VALIDATE
        parallel do
          step PASS
          step TOO_LONG
        end
      end

      result = pipeline.call(Result.new(1))

      assert_equal({ input: ['name missing', 'name too long'] }, result.errors)
    end

    def test_merge_parallel_errors_appends_only_what_each_branch_added
      input = Result.new(1).with_error(:input, 'name missing')
      branches = [
        input.with_error(:input, 'name too long'),
        input.with_error(:auth, 'denied'),
        input
      ]

      merged = Pipeline.new.send(:merge_parallel_errors, input, branches)

      assert_equal({ input: ['name missing', 'name too long'], auth: ['denied'] }, merged)
      assert_equal({ input: ['name missing'] }, input.errors, 'input errors must not be mutated')
    end

    def test_merge_parallel_errors_keeps_messages_of_a_branch_that_replaced_its_errors
      input = Result.new(1).with_error(:input, 'name missing')
      branches = [Result.new(1, errors: { input: ['rewritten'] })]

      merged = Pipeline.new.send(:merge_parallel_errors, input, branches)

      assert_equal({ input: ['name missing', 'rewritten'] }, merged)
    end
  end
end
