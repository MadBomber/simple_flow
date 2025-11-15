# SimpleFlow Examples

This directory contains comprehensive examples demonstrating the capabilities of the SimpleFlow gem.

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

## Examples Overview

### 1. Basic Pipeline (`01_basic_pipeline.rb`)

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

---

### 2. Error Handling (`02_error_handling.rb`)

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

---

### 3. Middleware (`03_middleware.rb`)

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

---

### 4. Automatic Parallel Discovery (`04_parallel_automatic.rb`)

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

---

### 5. Explicit Parallel Blocks (`05_parallel_explicit.rb`)

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

---

### 6. Real-World: E-commerce Order Processing (`06_real_world_ecommerce.rb`)

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

---

### 7. Real-World: Data ETL Pipeline (`07_real_world_etl.rb`)

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

### 8. Graph Visualization (`08_graph_visualization.rb`)

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

### 9. Pipeline Visualization (Direct) (`09_pipeline_visualization.rb`) ⭐ RECOMMENDED

**Demonstrates:**
- **Direct visualization from pipelines** (no manual graph creation!)
- Calling `pipeline.visualize_ascii` directly
- Exporting with `pipeline.visualize_dot`, `pipeline.visualize_mermaid`
- Getting execution plan with `pipeline.execution_plan`
- Checking if pipeline can be visualized
- Comparing different pipeline structures

**Key advantage:**
This example shows the **recommended approach** - visualizing pipelines directly without manually recreating dependency structures. The pipeline already knows its dependencies, so you can simply call visualization methods on it.

**API methods:**
- `pipeline.visualize_ascii()` - Terminal visualization
- `pipeline.visualize_dot()` - Graphviz export
- `pipeline.visualize_mermaid()` - Mermaid export
- `pipeline.execution_plan()` - Performance analysis
- `pipeline.dependency_graph()` - Get graph object
- `pipeline.visualize()` - Get visualizer object

**Run time:** ~1 second

**Note:** Only works with pipelines that have named steps (using `step :name, callable, depends_on: [...]`). Unnamed steps cannot be auto-visualized.

---

## Async Gem Availability

All parallel examples will automatically use the `async` gem if available for true concurrent execution. If not available, they fall back to sequential execution.

Check async availability:
```ruby
pipeline = SimpleFlow::Pipeline.new
puts pipeline.async_available?  # => true or false
```

## Learning Path

Recommended order for learning:

1. Start with `01_basic_pipeline.rb` to understand core concepts
2. Move to `02_error_handling.rb` for flow control
3. Explore `03_middleware.rb` for cross-cutting concerns
4. Learn parallel execution with `04_parallel_automatic.rb` and `05_parallel_explicit.rb`
5. See real-world applications in `06_real_world_ecommerce.rb` and `07_real_world_etl.rb`

## Customization

All examples are designed to be modified. Try:

- Adding your own steps to pipelines
- Creating custom middleware
- Changing dependency graphs
- Adding more error handling
- Integrating with real external services

## Performance Notes

- **Parallel execution** is most beneficial for I/O-bound operations (API calls, DB queries, file operations)
- **Sequential execution** may be faster for CPU-bound tasks due to Ruby's GIL
- Run examples multiple times to see consistent timing
- Actual speedup depends on system resources and async gem availability

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

## Additional Resources

- [SimpleFlow README](../README.md) - Full gem documentation
- [Test Suite](../test/) - More usage examples
- [Source Code](../lib/simple_flow/) - Implementation details

## Contributing Examples

Have a great use case? Consider contributing an example:

1. Follow the existing naming convention (`NN_description.rb`)
2. Include clear comments and output
3. Demonstrate a specific feature or pattern
4. Keep examples self-contained and runnable
5. Add an entry to this README

---

**Questions or Issues?**
Open an issue at: https://github.com/MadBomber/simple_flow/issues
