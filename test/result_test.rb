require_relative 'test_helper'

module SimpleFlow
  class ResultTest < Minitest::Test
    def test_initialize
      result = Result.new(10)
      assert_equal 10, result.value
      assert_empty result.context
      assert_empty result.errors
    end

    def test_initialize_with_context_and_errors
      result = Result.new(10, context: { user: 1 }, errors: { validation: ['error'] })
      assert_equal 10, result.value
      assert_equal({ user: 1 }, result.context)
      assert_equal({ validation: ['error'] }, result.errors)
      assert result.continue?
    end

    def test_with_context
      original = Result.new('orig')
      updated = original.with_context(:user, 1)

      refute_equal original.object_id, updated.object_id
      assert_equal 1, updated.context[:user]
    end

    def test_with_context_multiple
      result = Result.new('val')
        .with_context(:user, 1)
        .with_context(:action, 'create')
        .with_context(:timestamp, 12345)

      assert_equal 1, result.context[:user]
      assert_equal 'create', result.context[:action]
      assert_equal 12345, result.context[:timestamp]
      assert_equal 3, result.context.size
    end

    def test_with_context_preserves_continue_state
      halted = Result.new('val').halt
      updated = halted.with_context(:key, 'value')

      refute updated.continue?
      assert_equal 'value', updated.context[:key]
    end

    def test_with_context_overwrites_existing_key
      result = Result.new('val')
        .with_context(:key, 'old')
        .with_context(:key, 'new')

      assert_equal 'new', result.context[:key]
    end

    def test_with_error
      original = Result.new('orig')
      updated = original.with_error(:validation, 'Invalid')

      refute_equal original.object_id, updated.object_id
      assert_equal ['Invalid'], updated.errors[:validation]
    end

    def test_with_error_multiple_keys
      result = Result.new('val')
        .with_error(:validation, 'Invalid field')
        .with_error(:authentication, 'Token expired')
        .with_error(:authorization, 'No permission')

      assert_equal ['Invalid field'], result.errors[:validation]
      assert_equal ['Token expired'], result.errors[:authentication]
      assert_equal ['No permission'], result.errors[:authorization]
      assert_equal 3, result.errors.size
    end

    def test_with_error_appends_to_same_key
      result = Result.new('val')
        .with_error(:validation, 'Error 1')
        .with_error(:validation, 'Error 2')
        .with_error(:validation, 'Error 3')

      assert_equal ['Error 1', 'Error 2', 'Error 3'], result.errors[:validation]
    end

    def test_with_error_preserves_continue_state
      halted = Result.new('val').halt
      updated = halted.with_error(:key, 'error')

      refute updated.continue?
      assert_equal ['error'], updated.errors[:key]
    end

    def test_halt
      result = Result.new('keep')

      halted = result.halt
      assert_equal false, halted.continue?

      halted_with_value = result.halt('stop')
      refute_equal result.value, halted_with_value.value
      assert_equal 'stop', halted_with_value.value
      assert_equal false, halted_with_value.continue?
    end

    def test_halt_preserves_context_and_errors
      result = Result.new('val', context: { user: 1 }, errors: { e: ['err'] })
      halted = result.halt

      refute halted.continue?
      assert_equal({ user: 1 }, halted.context)
      assert_equal({ e: ['err'] }, halted.errors)
    end

    def test_halt_without_value_preserves_original
      result = Result.new('original').halt

      refute result.continue?
      assert_equal 'original', result.value
    end

    def test_halt_with_string_value
      result = Result.new('original').halt('stopped')

      refute result.continue?
      assert_equal 'stopped', result.value
    end

    def test_halt_with_numeric_value
      result = Result.new(10).halt(0)

      refute result.continue?
      assert_equal 0, result.value
    end

    def test_continue
      result = Result.new('start')
      continued = result.continue('go')

      assert_equal true, continued.continue?
      assert_equal 'go', continued.value
    end

    def test_continue_preserves_context_and_errors
      result = Result.new('val', context: { user: 1 }, errors: { e: ['err'] })
      continued = result.continue('new')

      assert continued.continue?
      assert_equal 'new', continued.value
      assert_equal({ user: 1 }, continued.context)
      assert_equal({ e: ['err'] }, continued.errors)
    end

    def test_continue_question
      result = Result.new('data')
      assert_equal true, result.continue?

      halted = result.halt
      refute_equal true, halted.continue?
    end

    def test_immutability_chain
      original = Result.new('start')
      step1 = original.with_context(:step, 1)
      step2 = step1.with_error(:error, 'oops')
      step3 = step2.continue('middle')
      step4 = step3.with_context(:step, 4)

      # Original unchanged
      assert_equal 'start', original.value
      assert_empty original.context
      assert_empty original.errors
      assert original.continue?

      # Each step is independent
      assert_equal 'start', step1.value
      assert_equal({ step: 1 }, step1.context)
      assert_empty step1.errors

      assert_equal 'start', step2.value
      assert_equal({ step: 1 }, step2.context)
      assert_equal({ error: ['oops'] }, step2.errors)

      assert_equal 'middle', step3.value
      assert_equal({ step: 1 }, step3.context)
      assert_equal({ error: ['oops'] }, step3.errors)

      assert_equal 'middle', step4.value
      assert_equal({ step: 4 }, step4.context)
      assert_equal({ error: ['oops'] }, step4.errors)
    end

    def test_halt_after_halt_preserves_state
      result = Result.new('val').halt.halt('new')

      refute result.continue?
      assert_equal 'new', result.value
    end

    def test_continue_after_halt_keeps_halted_state
      result = Result.new('val').halt.continue('new')

      refute result.continue?
      assert_equal 'new', result.value
    end

    def test_complex_workflow
      result = Result.new({ count: 0 })
        .with_context(:user_id, 123)
        .with_context(:timestamp, Time.now.to_i)
        .with_error(:validation, 'Field required')
        .continue({ count: 1 })
        .with_error(:validation, 'Invalid format')
        .with_context(:retries, 1)

      assert result.continue?
      assert_equal({ count: 1 }, result.value)
      assert_equal 123, result.context[:user_id]
      assert result.context[:timestamp]
      assert_equal 1, result.context[:retries]
      assert_equal ['Field required', 'Invalid format'], result.errors[:validation]
    end
  end
end

