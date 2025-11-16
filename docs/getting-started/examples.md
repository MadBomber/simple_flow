# SimpleFlow Examples

This page documents the comprehensive examples demonstrating the capabilities of the SimpleFlow gem.

## Running the Examples

All examples are executable Ruby scripts. Make sure you've installed the gem dependencies first:

```bash
bundle install
```

Then run any example:

```bash
ruby examples/01_basic_pipeline.rb
ruby examples/02_error_handling.rb
# ... etc
```

---

## Examples Overview

### 1. Basic Pipeline

**File:** `01_basic_pipeline.rb`

**Demonstrates:**

- Sequential step execution
- Data transformation
- Context propagation through steps
- Simple computational pipelines

**Key concepts:**

- Using `step` to define pipeline stages
- `result.continue(value)` to pass data forward
- `result.with_context(key, value)` to track metadata

**Run time:** ~2 seconds

```bash
ruby examples/01_basic_pipeline.rb
```

---

### 2. Error Handling

**File:** `02_error_handling.rb`

**Demonstrates:**

- Input validation with `halt`
- Error accumulation across steps
- Conditional flow control
- Role-based processing

**Key concepts:**

- `result.halt` to stop execution
- `result.with_error(key, message)` to track errors
- Checking `result.continue?` to see if pipeline should proceed
- Early termination prevents later steps from running

**Run time:** ~1 second

```bash
ruby examples/02_error_handling.rb
```

---

### 3. Middleware

**File:** `03_middleware.rb`

**Demonstrates:**

- Built-in logging middleware
- Built-in instrumentation middleware
- Stacking multiple middleware
- Custom middleware (retry logic, authentication)

**Key concepts:**

- `use_middleware ClassName, options` to add middleware
- Middleware wraps all steps in the pipeline
- Custom middleware by implementing `.new(callable, **options)` and `#call(result)`
- Middleware execution order (reverse of declaration)

**Run time:** ~3 seconds

```bash
ruby examples/03_middleware.rb
```

---

### 4. Automatic Parallel Discovery

**File:** `04_parallel_automatic.rb`

**Demonstrates:**

- Named steps with dependency declarations
- Automatic dependency graph construction
- Parallel execution of independent steps
- Complex multi-level dependency graphs
- Dependency graph visualization

**Key concepts:**

- `step :name, callable, depends_on: [...]` for named steps
- `call_parallel` to execute with automatic parallelism
- Steps with satisfied dependencies run concurrently
- Context and error merging from parallel steps

**Run time:** ~1-2 seconds (with async), ~3-4 seconds (without)

```bash
ruby examples/04_parallel_automatic.rb
```

---

### 5. Explicit Parallel Blocks

**File:** `05_parallel_explicit.rb`

**Demonstrates:**

- Explicit `parallel do...end` blocks
- Multiple parallel blocks in one pipeline
- Mixing sequential and parallel execution
- Error handling in parallel blocks
- Performance comparison vs sequential

**Key concepts:**

- `parallel do ... end` to define concurrent execution
- All steps in a parallel block run simultaneously
- Halting in any parallel step stops the pipeline
- Contexts from all parallel steps are merged

**Run time:** ~1 second (with async), ~2 seconds (without)

```bash
ruby examples/05_parallel_explicit.rb
```

---

### 6. Real-World: E-commerce Order Processing

**File:** `06_real_world_ecommerce.rb`

**Demonstrates:**

- Complete e-commerce order pipeline
- Integration with multiple services (inventory, payment, shipping)
- Parallel validation and data fetching
- Error handling at each stage
- Notifications in parallel

**Pipeline flow:**

1. Validate order
2. Check inventory + Calculate shipping (parallel)
3. Calculate totals
4. Process payment
5. Reserve inventory
6. Create shipment
7. Send email + SMS (parallel)
8. Finalize order

**Key concepts:**

- Real-world service integration patterns
- Dependency management for complex workflows
- Transaction-like behavior with halt on failure
- Parallel execution for independent operations

**Run time:** ~1-2 seconds

```bash
ruby examples/06_real_world_ecommerce.rb
```

---

### 7. Real-World: Data ETL Pipeline

**File:** `07_real_world_etl.rb`

**Demonstrates:**

- Extract, Transform, Load (ETL) pattern
- Multi-source data extraction in parallel
- Data transformation and normalization
- Data aggregation and analytics
- Data quality validation
- Output preparation

**Pipeline flow:**

1. **Extract:** Fetch users + orders + products (parallel)
2. **Transform:** Clean/normalize all data (parallel)
3. **Aggregate:** Compute statistics (parallel)
4. **Validate:** Check data quality
5. **Load:** Prepare final output

**Key concepts:**

- Parallel data loading from multiple sources
- Independent transformation pipelines
- Analytics computation from joined data
- Validation before output
- Metadata tracking

**Run time:** ~1-2 seconds

**Optional:** Run with `--save` flag to export JSON output:

```bash
ruby examples/07_real_world_etl.rb --save
```

---

### 8. Graph Visualization

**File:** `08_graph_visualization.rb`

**Demonstrates:**

- Visualizing dependency graphs
- ASCII art terminal output
- Exporting to Graphviz DOT format
- Exporting to Mermaid diagram format
- Generating interactive HTML visualizations
- Execution plan analysis
- Graph analytics and statistics

**Visualization formats:**

- **ASCII** - Terminal-friendly text representation
- **DOT** - Graphviz format for PNG/SVG/PDF generation
- **Mermaid** - Modern diagram syntax for web
- **HTML** - Interactive browser-based visualization
- **Execution Plan** - Detailed performance analysis

**Key concepts:**

- Understanding dependency relationships
- Identifying parallel execution opportunities
- Visualizing pipeline structure
- Analyzing graph performance characteristics
- Exporting for documentation

**Run time:** ~1 second

**Generates files:**

- `ecommerce_graph.dot` - For Graphviz
- `ecommerce_graph.mmd` - For Mermaid
- `ecommerce_graph.html` - Interactive visualization

**To generate images:**

```bash
# Install Graphviz first (brew install graphviz / apt-get install graphviz)
dot -Tpng ecommerce_graph.dot -o ecommerce_graph.png
dot -Tsvg ecommerce_graph.dot -o ecommerce_graph.svg
```

---

### 9. Pipeline Visualization (Direct)

**File:** `09_pipeline_visualization.rb`

!!! tip "Recommended Approach"
    This example shows the recommended approach - visualizing pipelines directly without manually recreating dependency structures.

**Demonstrates:**

- **Direct visualization from pipelines** (no manual graph creation!)
- Calling `pipeline.visualize_ascii` directly
- Exporting with `pipeline.visualize_dot`, `pipeline.visualize_mermaid`
- Getting execution plan with `pipeline.execution_plan`
- Checking if pipeline can be visualized
- Comparing different pipeline structures

**API methods:**

- `pipeline.visualize_ascii()` - Terminal visualization
- `pipeline.visualize_dot()` - Graphviz export
- `pipeline.visualize_mermaid()` - Mermaid export
- `pipeline.execution_plan()` - Performance analysis
- `pipeline.dependency_graph()` - Get graph object
- `pipeline.visualize()` - Get visualizer object

**Run time:** ~1 second

!!! note
    Only works with pipelines that have named steps (using `step :name, callable, depends_on: [...]` or `depends_on: :none`). Unnamed steps cannot be auto-visualized.

```bash
ruby examples/09_pipeline_visualization.rb
```

---

### 10. Concurrency Control

**File:** `10_concurrency_control.rb`

**Demonstrates:**

- Per-pipeline concurrency model selection
- Forcing threads vs async for different pipelines
- Mixing concurrency models in the same application
- Auto-detection behavior
- Error handling for unavailable concurrency models

**Key concepts:**

- `Pipeline.new(concurrency: :threads)` - Force thread-based execution
- `Pipeline.new(concurrency: :async)` - Require async gem (raises if unavailable)
- `Pipeline.new(concurrency: :auto)` - Auto-detect (default)
- Different pipelines can use different models in the same app

**Run time:** ~1-2 seconds

```bash
ruby examples/10_concurrency_control.rb
```

---

### 11. Sequential Dependencies

**File:** `11_sequential_dependencies.rb`

**Demonstrates:**

- Sequential step execution with automatic dependencies
- Pipeline short-circuiting when a step halts
- How unnamed steps depend on previous step's success
- Error propagation through the pipeline
- Comparison with parallel execution

**Key concepts:**

- Unnamed steps automatically depend on previous step
- `result.halt` stops the entire pipeline immediately
- Subsequent steps are never executed after a halt
- Errors accumulate and propagate through the result

**Run time:** ~1 second

```bash
ruby examples/11_sequential_dependencies.rb
```

---

### 12. Reserved Dependency Symbols

**File:** `12_none_constant.rb`

**Demonstrates:**

- Using `:none` symbol for cleaner "no dependencies" syntax
- Using `:nothing` as an alternative
- Comparison with empty array `[]` syntax
- Multiple independent root steps
- Filtering reserved symbols from dependency arrays

**Key concepts:**

- `depends_on: :none` is equivalent to `depends_on: []`
- More readable and semantic than empty array
- `:none` and `:nothing` are reserved symbols (cannot be step names)
- Symbols are automatically filtered from dependency arrays

**Run time:** ~1 second

```bash
ruby examples/12_none_constant.rb
```

---

## Async Gem Availability

All parallel examples will automatically use the `async` gem if available for true concurrent execution. If not available, they fall back to sequential execution.

Check async availability:

```ruby
pipeline = SimpleFlow::Pipeline.new
puts pipeline.async_available?  # => true or false
```

---

## Learning Path

Recommended order for learning:

1. Start with `01_basic_pipeline.rb` to understand core concepts
2. Move to `02_error_handling.rb` for flow control
3. Explore `03_middleware.rb` for cross-cutting concerns
4. Learn parallel execution with `04_parallel_automatic.rb` and `05_parallel_explicit.rb`
5. See real-world applications in `06_real_world_ecommerce.rb` and `07_real_world_etl.rb`
6. Explore visualization with `08_graph_visualization.rb` and `09_pipeline_visualization.rb`

---

## Customization

All examples are designed to be modified. Try:

- Adding your own steps to pipelines
- Creating custom middleware
- Changing dependency graphs
- Adding more error handling
- Integrating with real external services

---

## Performance Notes

- **Parallel execution** is most beneficial for I/O-bound operations (API calls, DB queries, file operations)
- **Sequential execution** may be faster for CPU-bound tasks due to Ruby's GIL
- Run examples multiple times to see consistent timing
- Actual speedup depends on system resources and async gem availability

---

## Troubleshooting

**Async gem not loading:**

```bash
bundle install
gem install async
```

**Permission errors on example files:**

```bash
chmod +x examples/*.rb
```

**Examples run sequentially despite async gem:**

- Check that async gem is properly installed
- Verify with `pipeline.async_available?`

---

## Next Steps

- [Core Concepts](../core-concepts/overview.md) - Understand the fundamentals
- [Concurrent Execution](../concurrent/introduction.md) - Deep dive into parallelism
- [API Reference](../api/pipeline.md) - Complete API documentation
