# Contributing to SimpleFlow

Thank you for your interest in contributing to SimpleFlow! This guide will help you get started.

## Getting Started

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
```bash
git clone https://github.com/YOUR_USERNAME/simple_flow.git
cd simple_flow
```

3. Add the upstream repository:
```bash
git remote add upstream https://github.com/madbomber/simple_flow.git
```

### Install Dependencies

```bash
bundle install
```

### Run Tests

```bash
bundle exec rake test
```

Expected output:
```
77 tests, 296 assertions, 0 failures, 0 errors, 0 skips
```

## Development Workflow

### 1. Create a Branch

Create a feature branch from `main`:

```bash
git checkout -b feature/your-feature-name
```

Branch naming conventions:
- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation changes
- `refactor/` - Code refactoring
- `test/` - Test additions or improvements

### 2. Make Your Changes

#### Code Style

SimpleFlow follows standard Ruby conventions. Please ensure:

- Use 2 spaces for indentation
- Keep lines under 120 characters when possible
- Add comments for complex logic
- Use descriptive variable names

#### Adding Features

When adding a new feature:

1. **Write tests first** (TDD approach)
2. Implement the feature
3. Update documentation
4. Add examples if applicable

#### Fixing Bugs

When fixing a bug:

1. Add a failing test that reproduces the bug
2. Fix the bug
3. Ensure the test passes
4. Consider adding regression tests

### 3. Run Tests

Run the full test suite:

```bash
bundle exec rake test
```

Run a specific test file:

```bash
ruby -Ilib:test test/pipeline_test.rb
```

Run a specific test:

```bash
ruby -Ilib:test test/pipeline_test.rb -n test_basic_pipeline
```

### 4. Update Documentation

If your changes affect user-facing behavior:

1. Update relevant documentation in `docs/`
2. Update the README if needed
3. Add or update code examples
4. Update CHANGELOG.md

### 5. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "Add feature: parallel execution for named steps

- Implement dependency graph analysis
- Add automatic parallel detection
- Include tests and documentation
"
```

Commit message guidelines:
- Use present tense ("Add feature" not "Added feature")
- First line should be under 72 characters
- Include a blank line after the first line
- Provide detailed description in the body if needed

### 6. Push and Create Pull Request

Push your branch:

```bash
git push origin feature/your-feature-name
```

Create a pull request on GitHub:
1. Go to the SimpleFlow repository
2. Click "New Pull Request"
3. Select your branch
4. Fill out the pull request template
5. Submit for review

## Pull Request Guidelines

### PR Template

```markdown
## Description

Brief description of what this PR does.

## Type of Change

- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Changes Made

- List of specific changes
- Another change
- And another

## Testing

Describe how you tested your changes:

- [ ] All existing tests pass
- [ ] Added new tests for new functionality
- [ ] Tested manually with examples

## Documentation

- [ ] Updated relevant documentation
- [ ] Updated CHANGELOG.md
- [ ] Added/updated code examples

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] No new warnings generated
- [ ] Tests added and passing
```

### Code Review Process

1. **Automated Checks**: GitHub Actions will run tests automatically
2. **Peer Review**: A maintainer will review your code
3. **Feedback**: Address any requested changes
4. **Approval**: Once approved, your PR will be merged

## Testing Guidelines

### Test Structure

Tests use Minitest:

```ruby
require 'test_helper'

class MyFeatureTest < Minitest::Test
  def setup
    # Setup code runs before each test
    @pipeline = SimpleFlow::Pipeline.new
  end

  def test_feature_works
    result = @pipeline.call(SimpleFlow::Result.new(42))

    assert result.continue?
    assert_equal 42, result.value
  end

  def test_handles_errors
    result = @pipeline.call(SimpleFlow::Result.new(nil))

    refute result.continue?
    assert result.errors.any?
  end
end
```

### Test Coverage

Aim for comprehensive test coverage:

- Test happy paths
- Test error conditions
- Test edge cases
- Test with various data types

Current test coverage: **96.61%** (121 tests, 296 assertions)

### Running Specific Tests

```bash
# Run all tests
bundle exec rake test

# Run specific test file
ruby -Ilib:test test/result_test.rb

# Run specific test method
ruby -Ilib:test test/result_test.rb -n test_with_context
```

## Documentation Guidelines

### Adding Documentation

When adding new features, update:

1. **API Reference** (`docs/api/`)
   - Complete method signatures
   - Parameters and return values
   - Examples

2. **Guides** (`docs/guides/`)
   - How-to guides
   - Best practices
   - Real-world examples

3. **README.md**
   - Overview of feature
   - Quick start example

### Documentation Style

- Use clear, concise language
- Include code examples
- Cross-reference related documentation
- Keep examples practical and realistic

## Project Structure

```
simple_flow/
├── lib/
│   └── simple_flow/
│       ├── dependency_graph.rb          # Dependency graph analysis
│       ├── dependency_graph_visualizer.rb # Visualization tools
│       ├── middleware.rb                # Built-in middleware
│       ├── parallel_executor.rb         # Parallel execution
│       ├── pipeline.rb                  # Pipeline orchestration
│       ├── result.rb                    # Result value object
│       ├── step_tracker.rb              # Step tracking
│       └── version.rb                   # Version number
├── test/
│   ├── test_helper.rb                   # Test configuration
│   ├── result_test.rb                   # Result tests
│   ├── pipeline_test.rb                 # Pipeline tests
│   ├── middleware_test.rb               # Middleware tests
│   ├── parallel_execution_test.rb       # Parallel execution tests
│   └── dependency_graph_test.rb         # Graph analysis tests
├── examples/
│   ├── 01_basic_pipeline.rb             # Basic usage
│   ├── 02_error_handling.rb             # Error patterns
│   ├── 03_middleware.rb                 # Middleware examples
│   ├── 04_parallel_automatic.rb         # Auto parallel
│   ├── 05_parallel_explicit.rb          # Explicit parallel
│   ├── 06_real_world_ecommerce.rb       # E-commerce example
│   ├── 07_real_world_etl.rb             # ETL example
│   ├── 08_graph_visualization.rb        # Graph viz
│   └── 09_pipeline_visualization.rb     # Pipeline viz
├── docs/                                # Documentation
└── CHANGELOG.md                         # Change history
```

## Adding Examples

When adding examples:

1. Place in `examples/` directory
2. Use clear, descriptive names
3. Include comments explaining the code
4. Make examples runnable
5. Demonstrate real-world use cases

Example template:

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'

# Description of what this example demonstrates

puts "=" * 60
puts "Example: Your Example Name"
puts "=" * 60
puts

# Your example code here

puts "\n" + "=" * 60
puts "Example completed!"
puts "=" * 60
```

## Releasing

(For maintainers only)

1. Update version in `lib/simple_flow/version.rb`
2. Update CHANGELOG.md
3. Commit changes
4. Create git tag: `git tag v0.x.x`
5. Push tag: `git push --tags`
6. Build gem: `gem build simple_flow.gemspec`
7. Push to RubyGems: `gem push simple_flow-0.x.x.gem`

## Getting Help

- **Issues**: Open an issue on GitHub
- **Discussions**: Use GitHub Discussions for questions
- **Email**: Contact maintainers directly for sensitive issues

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

## License

By contributing to SimpleFlow, you agree that your contributions will be licensed under the project's license.

## Thank You!

Your contributions make SimpleFlow better for everyone. Thank you for taking the time to contribute!
