# Installation

## Requirements

- Ruby >= 3.2.0
- Bundler (recommended)

## Installation Methods

### Using Bundler (Recommended)

Add SimpleFlow to your `Gemfile`:

```ruby
gem 'simple_flow'
```

Then install:

```bash
bundle install
```

### Using RubyGems

Install directly with gem:

```bash
gem install simple_flow
```

## Dependencies

- **logger** and **tsort** - no longer default gems as of Ruby 4.0/4.1; installed automatically
- **async** (~> 2.0) - optional; add it to your Gemfile for fiber-based parallel execution. Without it, parallel steps run on Ruby threads.

## Verifying Installation

After installation, verify SimpleFlow is working:

```ruby
require 'simple_flow'

pipeline = SimpleFlow::Pipeline.new do
  step ->(result) { result.continue("Hello, SimpleFlow!") }
end

result = pipeline.call(SimpleFlow::Result.new(nil))
puts result.value
# => "Hello, SimpleFlow!"
```

If this runs without errors, you're ready to go!

## Next Steps

- [Quick Start Guide](quick-start.md) - Build your first pipeline
- [Examples](examples.md) - See SimpleFlow in action
- [Core Concepts](../core-concepts/overview.md) - Understand the fundamentals
