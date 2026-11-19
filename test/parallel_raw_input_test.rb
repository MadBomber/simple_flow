# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/simple_flow'

module SimpleFlow
  # Parallel steps accept pipeline input that is not a Result, as the README
  # shows with call_parallel(raw_data)
  class ParallelRawInputTest < Minitest::Test
    def test_call_parallel_with_raw_input
      pipeline = Pipeline.new do
        step :a, ->(_r) { Result.new(1).with_context(:a, 1) }
        step :b, ->(_r) { Result.new(2).with_context(:b, 2) }
      end

      result = pipeline.call_parallel({ x: 1 })

      assert_equal({ a: 1, b: 2 }, result.context)
      assert_empty result.errors
    end

    def test_parallel_block_with_raw_input
      pipeline = Pipeline.new do
        parallel do
          step ->(_r) { Result.new(1).with_error(:a, 'bad') }
          step ->(_r) { Result.new(2) }
        end
      end

      result = pipeline.call({ x: 1 })

      assert_equal({ a: ['bad'] }, result.errors)
    end
  end
end
