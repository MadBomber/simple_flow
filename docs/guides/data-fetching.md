# Data Fetching Guide

This guide demonstrates how to fetch data from various sources using SimpleFlow, including APIs, databases, file systems, and external services.

## API Data Fetching

### Basic API Call

```ruby
step :fetch_from_api, ->(result) {
  begin
    response = HTTP.get("https://api.example.com/users/#{result.value}")
    data = JSON.parse(response.body)
    result.with_context(:user_data, data).continue(result.value)
  rescue HTTP::Error => e
    result.halt.with_error(:api, "API request failed: #{e.message}")
  rescue JSON::ParserError => e
    result.halt.with_error(:parse, "Invalid JSON: #{e.message}")
  end
}
```

### Parallel API Calls

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_weather, ->(result) {
    location = result.value[:location]
    weather = HTTP.get("https://api.weather.com/current?location=#{location}").parse
    result.with_context(:weather, weather).continue(result.value)
  }, depends_on: []

  step :fetch_news, ->(result) {
    topic = result.value[:topic]
    news = HTTP.get("https://api.news.com/articles?topic=#{topic}").parse
    result.with_context(:news, news).continue(result.value)
  }, depends_on: []

  step :fetch_stocks, ->(result) {
    symbols = result.value[:symbols]
    stocks = HTTP.get("https://api.stocks.com/quotes?symbols=#{symbols}").parse
    result.with_context(:stocks, stocks).continue(result.value)
  }, depends_on: []

  step :combine_results, ->(result) {
    combined = {
      weather: result.context[:weather],
      news: result.context[:news],
      stocks: result.context[:stocks]
    }
    result.continue(combined)
  }, depends_on: [:fetch_weather, :fetch_news, :fetch_stocks]
end

# All API calls execute in parallel
result = pipeline.call_parallel(
  SimpleFlow::Result.new({ location: "NYC", topic: "tech", symbols: "AAPL,GOOGL" })
)
```

### API with Authentication

```ruby
class AuthenticatedAPI
  def initialize(api_key)
    @api_key = api_key
  end

  def call(result)
    endpoint = result.value[:endpoint]

    response = HTTP
      .auth("Bearer #{@api_key}")
      .get("https://api.example.com/#{endpoint}")

    if response.status.success?
      data = JSON.parse(response.body)
      result.with_context(:api_response, data).continue(result.value)
    else
      result.halt.with_error(:api, "Request failed with status #{response.status}")
    end
  rescue StandardError => e
    result.halt.with_error(:api, "API error: #{e.message}")
  end
end

pipeline = SimpleFlow::Pipeline.new do
  step :fetch_data, AuthenticatedAPI.new(ENV['API_KEY']), depends_on: []
end
```

### Rate-Limited API Calls

```ruby
class RateLimitedFetcher
  def initialize(max_requests_per_second: 10)
    @max_requests = max_requests_per_second
    @request_times = []
  end

  def call(result)
    wait_if_rate_limited

    begin
      @request_times << Time.now
      response = HTTP.get(result.value[:url])
      data = response.parse

      result.with_context(:data, data).continue(result.value)
    rescue HTTP::Error => e
      result.halt.with_error(:http, e.message)
    end
  end

  private

  def wait_if_rate_limited
    # Remove old requests outside the time window
    one_second_ago = Time.now - 1
    @request_times.reject! { |time| time < one_second_ago }

    # Wait if we've hit the limit
    if @request_times.size >= @max_requests
      sleep(0.1)
      wait_if_rate_limited
    end
  end
end
```

## Database Queries

### Basic Database Query

```ruby
step :fetch_users, ->(result) {
  users = DB[:users]
    .where(active: true)
    .where { created_at > Date.today - 30 }
    .all

  result.with_context(:users, users).continue(result.value)
}
```

### Parallel Database Queries

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_users, ->(result) {
    users = DB[:users].where(active: true).all
    result.with_context(:users, users).continue(result.value)
  }, depends_on: []

  step :fetch_orders, ->(result) {
    orders = DB[:orders].where(status: 'completed').all
    result.with_context(:orders, orders).continue(result.value)
  }, depends_on: []

  step :fetch_products, ->(result) {
    products = DB[:products].where(in_stock: true).all
    result.with_context(:products, products).continue(result.value)
  }, depends_on: []

  step :aggregate, ->(result) {
    stats = {
      total_users: result.context[:users].size,
      total_orders: result.context[:orders].size,
      total_products: result.context[:products].size
    }
    result.continue(stats)
  }, depends_on: [:fetch_users, :fetch_orders, :fetch_products]
end

# Ensure your database connection pool supports concurrent queries
DB = Sequel.connect(
  'postgres://localhost/mydb',
  max_connections: 10  # Allow concurrent connections
)

result = pipeline.call_parallel(SimpleFlow::Result.new(nil))
```

### Complex Joins and Aggregations

```ruby
step :fetch_user_analytics, ->(result) {
  user_id = result.value

  analytics = DB[:users]
    .select(:users__id, :users__name)
    .select_append { count(:orders__id).as(:order_count) }
    .select_append { sum(:orders__total).as(:total_spent) }
    .left_join(:orders, user_id: :id)
    .where(users__id: user_id)
    .group(:users__id, :users__name)
    .first

  result.with_context(:analytics, analytics).continue(result.value)
}
```

## File System Operations

### Reading Files

```ruby
step :read_config, ->(result) {
  begin
    config_path = result.value[:config_path]
    content = File.read(config_path)
    config = JSON.parse(content)

    result.with_context(:config, config).continue(result.value)
  rescue Errno::ENOENT
    result.halt.with_error(:file, "Config file not found: #{config_path}")
  rescue JSON::ParserError => e
    result.halt.with_error(:parse, "Invalid JSON in config: #{e.message}")
  end
}
```

### Reading Multiple Files in Parallel

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :read_users_csv, ->(result) {
    users = CSV.read('data/users.csv', headers: true).map(&:to_h)
    result.with_context(:users, users).continue(result.value)
  }, depends_on: []

  step :read_products_json, ->(result) {
    products = JSON.parse(File.read('data/products.json'))
    result.with_context(:products, products).continue(result.value)
  }, depends_on: []

  step :read_config_yaml, ->(result) {
    config = YAML.load_file('config/settings.yml')
    result.with_context(:config, config).continue(result.value)
  }, depends_on: []

  step :combine_data, ->(result) {
    combined = {
      users: result.context[:users],
      products: result.context[:products],
      config: result.context[:config]
    }
    result.continue(combined)
  }, depends_on: [:read_users_csv, :read_products_json, :read_config_yaml]
end
```

### Processing Large Files

```ruby
step :process_large_file, ->(result) {
  file_path = result.value
  processed_count = 0

  File.foreach(file_path).each_slice(1000) do |batch|
    # Process in batches
    batch.each do |line|
      process_line(line)
      processed_count += 1
    end
  end

  result.with_context(:lines_processed, processed_count).continue(result.value)
}
```

## Caching Strategies

### Simple Cache with Fallback

```ruby
step :fetch_with_cache, ->(result) {
  cache_key = "user_#{result.value}"

  # Try cache first
  cached = REDIS.get(cache_key)
  if cached
    data = JSON.parse(cached)
    return result.with_context(:source, :cache).continue(data)
  end

  # Cache miss - fetch from API
  begin
    response = HTTP.get("https://api.example.com/users/#{result.value}")
    data = response.parse

    # Store in cache for 1 hour
    REDIS.setex(cache_key, 3600, data.to_json)

    result.with_context(:source, :api).continue(data)
  rescue HTTP::Error => e
    result.halt.with_error(:fetch, "Failed to fetch data: #{e.message}")
  end
}
```

### Multi-Level Caching

```ruby
class MultiLevelCache
  def self.call(result)
    key = result.value[:cache_key]

    # Level 1: Memory cache
    if data = MEMORY_CACHE[key]
      return result.with_context(:cache_level, :memory).continue(data)
    end

    # Level 2: Redis cache
    if cached = REDIS.get(key)
      data = JSON.parse(cached)
      MEMORY_CACHE[key] = data
      return result.with_context(:cache_level, :redis).continue(data)
    end

    # Level 3: Database
    if record = DB[:cache].where(key: key).first
      data = JSON.parse(record[:value])
      REDIS.setex(key, 3600, data.to_json)
      MEMORY_CACHE[key] = data
      return result.with_context(:cache_level, :database).continue(data)
    end

    # No cache hit - need to fetch
    result.with_context(:cache_level, :none).continue(nil)
  end
end
```

## Batch Processing

### Fetching Data in Batches

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :fetch_batch, ->(result) {
    batch_ids = result.value
    records = DB[:records].where(id: batch_ids).all

    result.with_context(:records, records).continue(result.value)
  }

  step :process_records, ->(result) {
    records = result.context[:records]
    processed = records.map { |r| transform_record(r) }

    result.continue(processed)
  }
end

# Process in batches
all_ids = (1..10000).to_a
all_ids.each_slice(100) do |batch|
  result = pipeline.call(SimpleFlow::Result.new(batch))
  save_processed_batch(result.value)
end
```

## Real-World ETL Example

```ruby
class ETLPipeline
  def self.build
    SimpleFlow::Pipeline.new do
      # Extract phase - parallel data loading
      step :extract_users, ->(result) {
        users = CSV.read('data/users.csv', headers: true).map(&:to_h)
        result.with_context(:raw_users, users).continue(result.value)
      }, depends_on: []

      step :extract_orders, ->(result) {
        orders = JSON.parse(File.read('data/orders.json'))
        result.with_context(:raw_orders, orders).continue(result.value)
      }, depends_on: []

      step :extract_products, ->(result) {
        products = DB[:products].all
        result.with_context(:raw_products, products).continue(result.value)
      }, depends_on: []

      # Transform phase - parallel transformations
      step :transform_users, ->(result) {
        users = result.context[:raw_users].map do |user|
          {
            id: user['id'].to_i,
            name: user['name'].strip.downcase,
            email: user['email'].downcase,
            created_at: Date.parse(user['signup_date'])
          }
        end
        result.with_context(:users, users).continue(result.value)
      }, depends_on: [:extract_users]

      step :transform_orders, ->(result) {
        orders = result.context[:raw_orders]
          .reject { |o| o['status'] == 'cancelled' }
          .map do |order|
            {
              id: order['order_id'],
              user_id: order['user_id'],
              total: order['amount'].to_f,
              items: order['items'].size
            }
          end
        result.with_context(:orders, orders).continue(result.value)
      }, depends_on: [:extract_orders]

      # Load phase - aggregate and save
      step :aggregate_stats, ->(result) {
        users = result.context[:users]
        orders = result.context[:orders]

        stats = users.map do |user|
          user_orders = orders.select { |o| o[:user_id] == user[:id] }
          {
            user_id: user[:id],
            total_orders: user_orders.size,
            total_spent: user_orders.sum { |o| o[:total] },
            avg_order: user_orders.empty? ? 0 : user_orders.sum { |o| o[:total] } / user_orders.size
          }
        end

        result.continue(stats)
      }, depends_on: [:transform_users, :transform_orders]

      step :save_results, ->(result) {
        DB[:user_stats].multi_insert(result.value)
        result.continue("Saved #{result.value.size} records")
      }, depends_on: [:aggregate_stats]
    end
  end
end

# Execute ETL pipeline
result = ETLPipeline.build.call_parallel(SimpleFlow::Result.new(nil))
puts result.value  # "Saved 150 records"
```

## Error Handling for Data Fetching

```ruby
step :fetch_with_retries, ->(result) {
  max_retries = 3
  attempt = 0

  begin
    attempt += 1
    response = HTTP.timeout(10).get(result.value[:url])
    data = response.parse

    result
      .with_context(:attempts, attempt)
      .with_context(:data, data)
      .continue(result.value)
  rescue HTTP::TimeoutError
    if attempt < max_retries
      sleep(attempt ** 2)  # Exponential backoff
      retry
    else
      result.halt.with_error(:timeout, "Request timed out after #{max_retries} attempts")
    end
  rescue HTTP::Error => e
    result.halt.with_error(:http, "HTTP error: #{e.message}")
  end
}
```

## Related Documentation

- [Error Handling](error-handling.md) - Handling errors during data fetching
- [File Processing](file-processing.md) - Advanced file processing techniques
- [Complex Workflows](complex-workflows.md) - Building complete data pipelines
- [Performance Guide](../concurrent/performance.md) - Optimizing data fetching
