# Optional Steps Guide

Optional steps allow you to build dynamic pipelines where the execution path is determined at runtime. Unlike regular steps that always execute (if their dependencies are met), optional steps only run when explicitly activated.

## Overview

Optional steps are declared with `depends_on: :optional` and are activated using `result.activate(:step_name)`. This enables powerful patterns like:

- **Router Pattern** - Route to different handlers based on data type
- **Soft Failure Pattern** - Graceful error handling with cleanup
- **Feature Flags** - Enable/disable functionality at runtime
- **Chained Activation** - Optional steps that activate other optional steps

## Declaring Optional Steps

Use `depends_on: :optional` to mark a step as optional:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :start, ->(r) { r.continue(r.value) }, depends_on: :none

  # This step will only run if explicitly activated
  step :optional_processor, ->(r) {
    r.continue(process(r.value))
  }, depends_on: :optional
end
```

## Activating Optional Steps

Use `result.activate(:step_name)` to add steps to the execution plan:

```ruby
# Activate a single step
result.activate(:optional_processor)

# Activate multiple steps at once
result.activate(:step_a, :step_b, :step_c)

# Chain activations
result
  .activate(:step_a)
  .activate(:step_b)
```

## Pattern 1: Router Pattern

The router pattern uses a decision step to route execution to different optional handlers based on the data being processed.

### Use Case: Document Processing

Process different document types with specialized handlers:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  # Router step - decides which processor to activate
  step :analyze_document, ->(result) {
    doc = result.value

    case doc[:type]
    when :pdf
      result.continue(doc).activate(:process_pdf)
    when :image
      result.continue(doc).activate(:process_image)
    when :spreadsheet
      result.continue(doc).activate(:process_spreadsheet)
    else
      result.continue(doc).activate(:process_generic)
    end
  }, depends_on: :none

  # Optional processors - only the activated one runs
  step :process_pdf, ->(result) {
    doc = result.value
    extracted = extract_pdf_text(doc)
    result.continue(doc.merge(text: extracted, processor: :pdf))
  }, depends_on: :optional

  step :process_image, ->(result) {
    doc = result.value
    extracted = run_ocr(doc)
    result.continue(doc.merge(text: extracted, processor: :image))
  }, depends_on: :optional

  step :process_spreadsheet, ->(result) {
    doc = result.value
    data = parse_cells(doc)
    result.continue(doc.merge(data: data, processor: :spreadsheet))
  }, depends_on: :optional

  step :process_generic, ->(result) {
    doc = result.value
    result.continue(doc.merge(processor: :generic))
  }, depends_on: :optional
end

# Usage
pdf_result = pipeline.call_parallel(
  SimpleFlow::Result.new({ type: :pdf, content: "..." })
)
# Only :analyze_document and :process_pdf execute

image_result = pipeline.call_parallel(
  SimpleFlow::Result.new({ type: :image, content: "..." })
)
# Only :analyze_document and :process_image execute
```

### Benefits

- **Clean Separation** - Each handler is isolated
- **Easy Extension** - Add new types without modifying existing code
- **Clear Intent** - The routing logic is explicit
- **Testability** - Each handler can be tested independently

## Pattern 2: Soft Failure Pattern

Instead of immediately halting on errors, activate error handling and cleanup steps. This allows for graceful degradation, proper logging, and resource cleanup.

### Use Case: Order Processing with Recovery

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :validate_order, ->(result) {
    order = result.value

    if order[:items].empty?
      # Instead of halt, activate error handlers
      result
        .with_error(:validation, "Order has no items")
        .continue(order.merge(failed_at: :validate_order))
        .activate(:handle_error, :cleanup)
    else
      result.continue(order.merge(validated: true))
    end
  }, depends_on: :none

  step :process_payment, ->(result) {
    order = result.value
    return result if order[:failed_at]  # Skip if already failed

    if payment_declined?(order)
      result
        .with_error(:payment, "Payment declined")
        .continue(order.merge(failed_at: :process_payment))
        .activate(:handle_error, :cleanup)
    else
      result.continue(order.merge(paid: true))
    end
  }, depends_on: [:validate_order]

  step :fulfill_order, ->(result) {
    order = result.value
    return result if order[:failed_at]

    result.continue(order.merge(fulfilled: true))
  }, depends_on: [:process_payment]

  # Error handling step - logs, alerts, etc.
  step :handle_error, ->(result) {
    order = result.value
    log_error(order[:failed_at], result.errors)
    send_alert(order)
    result
      .with_context(:error_logged, true)
      .continue(order.merge(error_handled: true))
  }, depends_on: :optional

  # Cleanup step - releases resources, then halts
  step :cleanup, ->(result) {
    order = result.value

    refund_payment(order) if order[:paid]
    release_inventory(order) if order[:inventory_reserved]

    result
      .continue(order.merge(cleaned_up: true, status: :failed))
      .halt  # Now we halt after cleanup
  }, depends_on: :optional
end
```

### Benefits

- **Graceful Degradation** - Proper cleanup before stopping
- **Auditability** - All errors are logged before halting
- **Resource Safety** - Reservations are released, payments refunded
- **Flexibility** - Different error types can trigger different handlers

## Pattern 3: Chained Optional Activation

Optional steps can activate other optional steps, creating dynamic chains:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :check_eligibility, ->(result) {
    user = result.value

    if user[:tier] == :gold && user[:years] >= 2
      result.continue(user).activate(:upgrade_to_platinum)
    elsif user[:tier] == :silver && user[:years] >= 1
      result.continue(user).activate(:upgrade_to_gold)
    else
      result.continue(user.merge(upgrade: :none))
    end
  }, depends_on: :none

  step :upgrade_to_gold, ->(result) {
    user = result.value
    new_user = user.merge(tier: :gold, benefits: [:priority_support])

    # Gold upgrade also triggers loyalty bonus
    result.continue(new_user).activate(:apply_loyalty_bonus)
  }, depends_on: :optional

  step :upgrade_to_platinum, ->(result) {
    user = result.value
    new_user = user.merge(tier: :platinum, benefits: [:concierge, :events])

    # Platinum triggers BOTH loyalty bonus AND special gift
    result.continue(new_user).activate(:apply_loyalty_bonus, :send_special_gift)
  }, depends_on: :optional

  step :apply_loyalty_bonus, ->(result) {
    user = result.value
    bonus = user[:years] * 1000
    result.continue(user.merge(bonus_points: bonus))
  }, depends_on: :optional

  step :send_special_gift, ->(result) {
    user = result.value
    schedule_gift_delivery(user)
    result.continue(user.merge(gift_scheduled: true))
  }, depends_on: :optional
end
```

## Pattern 4: Feature Flags

Use optional steps to enable/disable features at runtime:

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :start, ->(result) {
    config = result.value[:config]
    activations = []

    activations << :enhanced_logging if config[:enhanced_logging]
    activations << :analytics if config[:analytics_enabled]
    activations << :rate_limiting if config[:rate_limiting]

    result.continue(result.value).activate(*activations)
  }, depends_on: :none

  step :process, ->(r) { r.continue(process(r.value)) }, depends_on: [:start]

  step :enhanced_logging, ->(result) {
    log_detailed(result)
    result.continue(result.value)
  }, depends_on: :optional

  step :analytics, ->(result) {
    track_event(result)
    result.continue(result.value)
  }, depends_on: :optional

  step :rate_limiting, ->(result) {
    check_rate_limit(result)
    result.continue(result.value)
  }, depends_on: :optional
end
```

## Execution Order

Optional steps are injected into the DAG when activated:

1. Pipeline starts with only non-optional steps in the execution plan
2. When a step calls `activate(:optional_step)`, the step is added to the plan
3. The activated step runs when all its dependencies are satisfied
4. If an optional step depends on another optional step, both must be activated

```ruby
# This step won't run unless BOTH :a and :b are activated
step :c, ->(r) { ... }, depends_on: [:a, :b]
# where :a and :b are optional
```

## Error Handling

### Unknown Step

Activating an unknown step raises `ArgumentError`:

```ruby
step :start, ->(result) {
  result.activate(:nonexistent)  # Raises ArgumentError
}, depends_on: :none
```

Error message: `Step :start attempted to activate unknown step :nonexistent`

### Non-Optional Step

Activating a non-optional step raises `ArgumentError`:

```ruby
step :regular, ->(r) { r.continue(r.value) }, depends_on: :none
step :start, ->(result) {
  result.activate(:regular)  # Raises ArgumentError
}, depends_on: :none
```

Error message: `Step :start attempted to activate non-optional step :regular. Only steps declared with depends_on: :optional can be activated.`

### Idempotent Activation

Activating the same step multiple times is safe:

```ruby
result
  .activate(:step_a)
  .activate(:step_a)  # No-op, step_a already activated
  .activate(:step_a)  # Still no-op
```

## Best Practices

### 1. Optional Steps as Terminal Paths

Optional steps work best when they are complete processing paths:

```ruby
# Good - each optional step is a complete path
step :process_pdf, ->(r) {
  extract_text(r.value)
  store_document(r.value)
  r.continue(r.value.merge(processed: true))
}, depends_on: :optional

# Avoid - splitting optional processing across multiple steps
# (harder to reason about execution order)
```

### 2. Use the Skip Pattern for Non-Optional Steps

When optional steps might not run, non-optional steps should handle missing data:

```ruby
step :process_data, ->(result) {
  # Skip if we're in error state (from soft failure pattern)
  return result if result.value[:failed_at]

  # Normal processing
  result.continue(process(result.value))
}, depends_on: [:validate]
```

### 3. Activate Early, Act Later

Activate steps as early as possible so the DAG can be properly built:

```ruby
# Good - activate immediately based on data
step :router, ->(result) {
  result.continue(result.value).activate(:handler)
}, depends_on: :none

# Avoid - activating after complex processing
# (makes execution flow harder to follow)
```

### 4. Document Activation Requirements

Make it clear which steps can activate which optional steps:

```ruby
# Only :router can activate these handlers
step :process_pdf, ->(r) { ... }, depends_on: :optional
step :process_image, ->(r) { ... }, depends_on: :optional

# Only :upgrade steps can activate these bonuses
step :apply_loyalty_bonus, ->(r) { ... }, depends_on: :optional
step :send_special_gift, ->(r) { ... }, depends_on: :optional
```

## Testing Optional Steps

### Test Activation Logic

```ruby
def test_router_activates_pdf_processor
  pipeline = build_document_pipeline
  result = SimpleFlow::Result.new({ type: :pdf })

  output = pipeline.call_parallel(result)

  assert_equal :pdf, output.value[:processor]
end

def test_router_activates_image_processor
  pipeline = build_document_pipeline
  result = SimpleFlow::Result.new({ type: :image })

  output = pipeline.call_parallel(result)

  assert_equal :image, output.value[:processor]
end
```

### Test Error Handling

```ruby
def test_soft_failure_activates_cleanup
  pipeline = build_order_pipeline
  result = SimpleFlow::Result.new({ items: [] })  # Invalid order

  output = pipeline.call_parallel(result)

  refute output.continue?
  assert output.value[:cleaned_up]
  assert output.value[:error_handled]
end
```

### Test Chained Activation

```ruby
def test_gold_upgrade_activates_loyalty_bonus
  pipeline = build_upgrade_pipeline
  result = SimpleFlow::Result.new({ tier: :silver, years: 2 })

  output = pipeline.call_parallel(result)

  assert_equal :gold, output.value[:tier]
  assert output.value[:bonus_points]
end
```

## Related Documentation

- [Steps](../core-concepts/steps.md) - Step types and contracts
- [Result API](../api/result.md) - The `activate` method
- [Pipeline API](../api/pipeline.md) - The `optional_steps` attribute
- [Error Handling](error-handling.md) - Error handling patterns
- [Example 13](https://github.com/MadBomber/simple_flow/blob/main/examples/13_optional_steps_in_dynamic_dag.rb) - Complete code examples
