# Validation Patterns

This guide presents common validation patterns used with SimpleFlow for data validation, business rule enforcement, and input sanitization.

## Basic Validation Patterns

### Required Fields

```ruby
step :validate_required, ->(result) {
  data = result.value
  required = [:name, :email, :password]
  missing = required.reject { |field| data[field] && !data[field].empty? }

  if missing.any?
    result.halt.with_error(:required, "Missing fields: #{missing.join(', ')}")
  else
    result.continue(data)
  end
}
```

### Format Validation

```ruby
step :validate_formats, ->(result) {
  data = result.value
  errors = []

  unless data[:email] =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    errors << "Invalid email format"
  end

  unless data[:phone] =~ /\A\+?\d{10,15}\z/
    errors << "Invalid phone format"
  end

  if errors.any?
    result.halt.with_error(:format, errors.join(", "))
  else
    result.continue(data)
  end
}
```

### Range Validation

```ruby
step :validate_ranges, ->(result) {
  data = result.value

  if data[:age] && (data[:age] < 0 || data[:age] > 120)
    return result.halt.with_error(:range, "Age must be between 0 and 120")
  end

  if data[:quantity] && data[:quantity] < 1
    return result.halt.with_error(:range, "Quantity must be at least 1")
  end

  result.continue(data)
}
```

## Type Validation

### Type Checking

```ruby
step :validate_types, ->(result) {
  data = result.value
  type_specs = {
    name: String,
    age: Integer,
    active: [TrueClass, FalseClass],
    tags: Array
  }

  errors = type_specs.map do |field, expected_type|
    value = data[field]
    next if value.nil?

    expected = Array(expected_type)
    unless expected.any? { |type| value.is_a?(type) }
      "#{field} must be #{expected.join(' or ')}, got #{value.class}"
    end
  end.compact

  if errors.any?
    result.halt.with_error(:type, errors.join(", "))
  else
    result.continue(data)
  end
}
```

## Parallel Validation

### Independent Field Validation

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :validate_email, ->(result) {
    unless valid_email?(result.value[:email])
      result.with_error(:email, "Invalid email")
    end
    result.continue(result.value)
  }, depends_on: []

  step :validate_password, ->(result) {
    password = result.value[:password]
    errors = []
    errors << "Too short" if password.length < 8
    errors << "Need uppercase" unless password =~ /[A-Z]/
    errors << "Need number" unless password =~ /[0-9]/

    errors.each { |err| result = result.with_error(:password, err) }
    result.continue(result.value)
  }, depends_on: []

  step :validate_phone, ->(result) {
    unless valid_phone?(result.value[:phone])
      result.with_error(:phone, "Invalid phone")
    end
    result.continue(result.value)
  }, depends_on: []

  step :check_errors, ->(result) {
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue(result.value)
    end
  }, depends_on: [:validate_email, :validate_password, :validate_phone]
end
```

## Business Rule Validation

### Single Rule Validation

```ruby
step :validate_business_rules, ->(result) {
  order = result.value

  # Maximum order amount
  if order[:total] > 10000
    return result.halt.with_error(:business, "Order exceeds maximum amount")
  end

  # Minimum order for free shipping
  if order[:total] < 50 && order[:shipping_method] == :free
    return result.halt.with_error(:business, "Free shipping requires $50 minimum")
  end

  # Age restriction
  if order[:items].any? { |i| i[:age_restricted] } && order[:customer][:age] < 21
    return result.halt.with_error(:business, "Age-restricted items require customer to be 21+")
  end

  result.continue(order)
}
```

### Conditional Business Rules

```ruby
step :apply_discount_rules, ->(result) {
  order = result.value
  customer = result.context[:customer]

  discount = 0

  # VIP customers get 20% off
  if customer[:vip]
    discount = [discount, 0.20].max
  end

  # Orders over $100 get 10% off
  if order[:subtotal] > 100
    discount = [discount, 0.10].max
  end

  # First-time customers get 15% off
  if customer[:order_count] == 0
    discount = [discount, 0.15].max
  end

  result
    .with_context(:discount_rate, discount)
    .with_context(:discount_amount, order[:subtotal] * discount)
    .continue(order)
}
```

## Custom Validators

### Reusable Validator Classes

```ruby
class EmailValidator
  def self.call(result)
    email = result.value[:email]

    errors = []
    errors << "Email is required" if email.nil? || email.empty?
    errors << "Invalid email format" unless email =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i

    if errors.any?
      errors.each { |error| result = result.with_error(:email, error) }
    end

    result.continue(result.value)
  end
end

class PasswordValidator
  MIN_LENGTH = 8

  def self.call(result)
    password = result.value[:password]

    errors = []
    errors << "Password is required" if password.nil? || password.empty?
    errors << "Password too short" if password && password.length < MIN_LENGTH
    errors << "Must contain uppercase" unless password =~ /[A-Z]/
    errors << "Must contain lowercase" unless password =~ /[a-z]/
    errors << "Must contain number" unless password =~ /[0-9]/

    if errors.any?
      errors.each { |error| result = result.with_error(:password, error) }
    end

    result.continue(result.value)
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step :validate_email, EmailValidator, depends_on: []
  step :validate_password, PasswordValidator, depends_on: []

  step :check_validations, ->(result) {
    if result.errors.any?
      result.halt(result.value)
    else
      result.continue(result.value)
    end
  }, depends_on: [:validate_email, :validate_password]
end
```

## Cross-Field Validation

### Dependent Fields

```ruby
step :validate_shipping, ->(result) {
  order = result.value

  # If express shipping is selected, shipping address is required
  if order[:shipping_method] == :express
    unless order[:shipping_address]
      return result.halt.with_error(:shipping, "Express shipping requires address")
    end
  end

  # If international shipping, country is required
  if order[:international]
    unless order[:shipping_address][:country]
      return result.halt.with_error(:shipping, "International shipping requires country")
    end
  end

  result.continue(order)
}
```

### Mutually Exclusive Fields

```ruby
step :validate_payment, ->(result) {
  payment = result.value[:payment]

  methods_present = [
    payment[:credit_card],
    payment[:paypal],
    payment[:bank_transfer]
  ].count { |m| m }

  if methods_present == 0
    result.halt.with_error(:payment, "Payment method required")
  elsif methods_present > 1
    result.halt.with_error(:payment, "Only one payment method allowed")
  else
    result.continue(result.value)
  end
}
```

## External Validation

### API-Based Validation

```ruby
step :validate_address, ->(result) {
  begin
    address = result.value[:shipping_address]
    validation = AddressValidator.validate(address)

    if validation[:valid]
      result
        .with_context(:validated_address, validation[:normalized])
        .continue(result.value)
    else
      result.halt.with_error(:address, validation[:errors].join(", "))
    end
  rescue AddressValidator::Error => e
    result.halt.with_error(:validation_service, "Address validation failed: #{e.message}")
  end
}
```

### Database Validation

```ruby
step :validate_unique_email, ->(result) {
  email = result.value[:email]

  if User.exists?(email: email)
    result.halt.with_error(:uniqueness, "Email already registered")
  else
    result.continue(result.value)
  end
}

step :validate_referral_code, ->(result) {
  code = result.value[:referral_code]
  return result.continue(result.value) if code.nil?

  referrer = User.find_by(referral_code: code)
  if referrer
    result.with_context(:referrer, referrer).continue(result.value)
  else
    result.halt.with_error(:referral, "Invalid referral code")
  end
}
```

## Sanitization and Normalization

### Data Cleaning

```ruby
step :sanitize_input, ->(result) {
  data = result.value

  sanitized = {
    name: data[:name]&.strip&.gsub(/\s+/, ' '),
    email: data[:email]&.downcase&.strip,
    phone: data[:phone]&.gsub(/[^\d+]/, ''),
    bio: data[:bio]&.strip&.slice(0, 500)
  }

  result.continue(sanitized)
}
```

### Data Normalization

```ruby
step :normalize_address, ->(result) {
  address = result.value

  normalized = {
    street: address[:street]&.upcase,
    city: address[:city]&.titleize,
    state: address[:state]&.upcase,
    zip: address[:zip]&.gsub(/[^\d-]/, ''),
    country: address[:country]&.upcase
  }

  result.continue(normalized)
}
```

## Validation Middleware

### Automatic Validation Middleware

```ruby
class ValidationMiddleware
  def initialize(callable, validator:)
    @callable = callable
    @validator = validator
  end

  def call(result)
    validation_result = @validator.call(result)

    if validation_result.errors.any?
      validation_result.halt(validation_result.value)
    else
      @callable.call(validation_result)
    end
  end
end

pipeline = SimpleFlow::Pipeline.new do
  use_middleware ValidationMiddleware, validator: EmailValidator

  step ->(result) {
    # Only executes if email validation passes
    result.continue("Email validated: #{result.value[:email]}")
  }
end
```

## Complete Example

```ruby
class UserRegistrationPipeline
  def self.build
    SimpleFlow::Pipeline.new do
      # Sanitize inputs
      step :sanitize, ->(result) {
        data = result.value
        sanitized = {
          name: data[:name]&.strip,
          email: data[:email]&.downcase&.strip,
          phone: data[:phone]&.gsub(/[^\d+]/, ''),
          password: data[:password]
        }
        result.continue(sanitized)
      }, depends_on: []

      # Parallel validations
      step :validate_name, ->(result) {
        if result.value[:name].nil? || result.value[:name].empty?
          result.with_error(:name, "Name is required")
        else
          result.continue(result.value)
        end
      }, depends_on: [:sanitize]

      step :validate_email, EmailValidator, depends_on: [:sanitize]
      step :validate_password, PasswordValidator, depends_on: [:sanitize]
      step :validate_phone, ->(result) {
        phone = result.value[:phone]
        unless phone =~ /\A\+?\d{10,15}\z/
          result.with_error(:phone, "Invalid phone format")
        end
        result.continue(result.value)
      }, depends_on: [:sanitize]

      # Check uniqueness
      step :check_uniqueness, ->(result) {
        if User.exists?(email: result.value[:email])
          result.with_error(:email, "Email already registered")
        end
        result.continue(result.value)
      }, depends_on: [:validate_email]

      # Verify all validations passed
      step :verify, ->(result) {
        if result.errors.any?
          result.halt(result.value)
        else
          result.continue(result.value)
        end
      }, depends_on: [:validate_name, :validate_email, :validate_password, :validate_phone, :check_uniqueness]

      # Create user
      step :create_user, ->(result) {
        user = User.create!(result.value)
        result.continue(user)
      }, depends_on: [:verify]
    end
  end
end

# Usage
result = UserRegistrationPipeline.build.call_parallel(
  SimpleFlow::Result.new(user_params)
)

if result.continue?
  redirect_to dashboard_path, notice: "Welcome!"
else
  render :new, errors: result.errors
end
```

## Related Documentation

- [Error Handling](error-handling.md) - Comprehensive error handling strategies
- [Complex Workflows](complex-workflows.md) - Building sophisticated pipelines
- [Result API](../api/result.md) - Result class reference
