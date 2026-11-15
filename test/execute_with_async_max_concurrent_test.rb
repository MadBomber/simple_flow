# frozen_string_literal: true

require 'minitest/autorun'
require 'timeout'
require_relative '../lib/simple_flow'

module SimpleFlow
  # F-122: execute_with_async is a documented entry point, so it rejects a
  # max_concurrent below 1 itself instead of hanging on Async::Semaphore.new(0)
  class ExecuteWithAsyncMaxConcurrentTest < Minitest::Test
    def setup
      skip 'async gem not available' unless ParallelExecutor.async_available?

      @steps  = [->(r) { r.continue(r.value) }, ->(r) { r.continue(r.value) }]
      @result = Result.new(0)
    end

    def execute_with(max_concurrent)
      Timeout.timeout(2) do
        ParallelExecutor.execute_with_async(@steps, @result, max_concurrent: max_concurrent)
      end
    end

    def test_zero_raises
      error = assert_raises(ArgumentError) { execute_with(0) }
      assert_match(/max_concurrent must be a positive Integer or nil, got 0/, error.message)
    end

    def test_negative_raises
      assert_raises(ArgumentError) { execute_with(-1) }
    end

    def test_nil_and_positive_integer_still_run
      [nil, 1].each do |max_concurrent|
        assert_equal [0, 0], execute_with(max_concurrent).map(&:value)
      end
    end
  end
end
