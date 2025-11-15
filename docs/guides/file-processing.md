# File Processing Guide

This guide demonstrates how to process files efficiently using SimpleFlow, including reading, writing, transforming, and validating file content.

## Reading Files

### Basic File Reading

```ruby
step :read_file, ->(result) {
  begin
    filepath = result.value
    content = File.read(filepath)
    result.with_context(:content, content).continue(filepath)
  rescue Errno::ENOENT
    result.halt.with_error(:file, "File not found: #{filepath}")
  rescue Errno::EACCES
    result.halt.with_error(:file, "Permission denied: #{filepath}")
  end
}
```

### Reading JSON Files

```ruby
step :read_json, ->(result) {
  begin
    content = File.read(result.value)
    data = JSON.parse(content)
    result.continue(data)
  rescue JSON::ParserError => e
    result.halt.with_error(:parse, "Invalid JSON: #{e.message}")
  end
}
```

### Reading CSV Files

```ruby
step :read_csv, ->(result) {
  begin
    rows = CSV.read(result.value, headers: true)
    data = rows.map(&:to_h)
    result.continue(data)
  rescue CSV::MalformedCSVError => e
    result.halt.with_error(:parse, "Malformed CSV: #{e.message}")
  end
}
```

### Reading YAML Files

```ruby
step :read_yaml, ->(result) {
  begin
    data = YAML.load_file(result.value)
    result.continue(data)
  rescue Psych::SyntaxError => e
    result.halt.with_error(:parse, "Invalid YAML: #{e.message}")
  end
}
```

## Writing Files

### Writing Text Files

```ruby
step :write_file, ->(result) {
  begin
    filepath = result.value[:path]
    content = result.value[:content]

    File.write(filepath, content)
    result.with_context(:bytes_written, content.bytesize).continue(filepath)
  rescue Errno::EACCES
    result.halt.with_error(:file, "Permission denied: #{filepath}")
  rescue Errno::ENOSPC
    result.halt.with_error(:file, "No space left on device")
  end
}
```

### Writing JSON Files

```ruby
step :write_json, ->(result) {
  filepath = result.value[:path]
  data = result.value[:data]

  json_content = JSON.pretty_generate(data)
  File.write(filepath, json_content)

  result.with_context(:path, filepath).continue(data)
}
```

### Writing CSV Files

```ruby
step :write_csv, ->(result) {
  filepath = result.value[:path]
  rows = result.value[:rows]

  CSV.open(filepath, 'w', write_headers: true, headers: rows.first.keys) do |csv|
    rows.each { |row| csv << row.values }
  end

  result.with_context(:rows_written, rows.size).continue(filepath)
}
```

## Processing Large Files

### Line-by-Line Processing

```ruby
step :process_large_file, ->(result) {
  filepath = result.value
  processed = 0

  File.foreach(filepath) do |line|
    process_line(line.strip)
    processed += 1
  end

  result.with_context(:lines_processed, processed).continue(filepath)
}
```

### Batch Processing

```ruby
step :process_in_batches, ->(result) {
  filepath = result.value
  batch_size = 1000
  batches_processed = 0

  File.foreach(filepath).each_slice(batch_size) do |batch|
    # Process batch
    transformed = batch.map { |line| transform(line) }
    save_batch(transformed)
    batches_processed += 1
  end

  result.with_context(:batches_processed, batches_processed).continue(filepath)
}
```

### Streaming Large Files

```ruby
step :stream_process, ->(result) {
  input_path = result.value[:input]
  output_path = result.value[:output]

  File.open(output_path, 'w') do |output|
    File.foreach(input_path) do |line|
      transformed = transform_line(line)
      output.write(transformed)
    end
  end

  result.continue(output_path)
}
```

## Multi-File Processing

### Processing Multiple Files in Parallel

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :process_config, ->(result) {
    config = JSON.parse(File.read('config/app.json'))
    result.with_context(:config, config).continue(result.value)
  }, depends_on: []

  step :process_users, ->(result) {
    users = CSV.read('data/users.csv', headers: true).map(&:to_h)
    result.with_context(:users, users).continue(result.value)
  }, depends_on: []

  step :process_logs, ->(result) {
    logs = File.readlines('logs/app.log').map(&:strip)
    result.with_context(:logs, logs).continue(result.value)
  }, depends_on: []

  step :combine_results, ->(result) {
    {
      config: result.context[:config],
      user_count: result.context[:users].size,
      log_count: result.context[:logs].size
    }
  }, depends_on: [:process_config, :process_users, :process_logs]
end

result = pipeline.call_parallel(SimpleFlow::Result.new(nil))
```

### Directory Processing

```ruby
step :process_directory, ->(result) {
  dir_path = result.value
  processed_files = []

  Dir.glob(File.join(dir_path, '*.json')).each do |filepath|
    data = JSON.parse(File.read(filepath))
    transformed = transform_data(data)
    processed_files << { file: filepath, records: transformed.size }
  end

  result.with_context(:processed_files, processed_files).continue(dir_path)
}
```

## Data Transformation

### CSV to JSON Conversion

```ruby
pipeline = SimpleFlow::Pipeline.new do
  step :read_csv, ->(result) {
    rows = CSV.read(result.value, headers: true)
    result.continue(rows.map(&:to_h))
  }

  step :transform_data, ->(result) {
    transformed = result.value.map do |row|
      {
        id: row['id'].to_i,
        name: row['name'].strip,
        email: row['email'].downcase,
        active: row['active'] == 'true'
      }
    end
    result.continue(transformed)
  }

  step :write_json, ->(result) {
    output_path = result.value.first['source'] + '.json'
    File.write(output_path, JSON.pretty_generate(result.value))
    result.continue(output_path)
  }
end
```

### File Format Conversion Pipeline

```ruby
class FileConverter
  def self.build(input_format:, output_format:)
    SimpleFlow::Pipeline.new do
      step :read_input, reader_for(input_format), depends_on: []
      step :transform, ->(result) {
        # Normalize to common format
        result.continue(normalize_data(result.value))
      }, depends_on: [:read_input]
      step :write_output, writer_for(output_format), depends_on: [:transform]
    end
  end

  def self.reader_for(format)
    case format
    when :json then ->(result) { JSON.parse(File.read(result.value)) }
    when :csv then ->(result) { CSV.read(result.value, headers: true).map(&:to_h) }
    when :yaml then ->(result) { YAML.load_file(result.value) }
    end
  end

  def self.writer_for(format)
    case format
    when :json then ->(result) { File.write(result.value[:output], JSON.pretty_generate(result.value[:data])) }
    when :csv then ->(result) { write_csv(result.value[:output], result.value[:data]) }
    when :yaml then ->(result) { File.write(result.value[:output], result.value[:data].to_yaml) }
    end
  end
end
```

## File Validation

### Validating File Existence

```ruby
step :validate_file_exists, ->(result) {
  filepath = result.value

  unless File.exist?(filepath)
    return result.halt.with_error(:file, "File does not exist: #{filepath}")
  end

  unless File.readable?(filepath)
    return result.halt.with_error(:file, "File is not readable: #{filepath}")
  end

  result.continue(filepath)
}
```

### Validating File Format

```ruby
step :validate_json_format, ->(result) {
  begin
    content = File.read(result.value)
    JSON.parse(content)  # Just validate, don't use result yet
    result.continue(result.value)
  rescue JSON::ParserError => e
    result.halt.with_error(:format, "Invalid JSON file: #{e.message}")
  end
}
```

### Validating File Size

```ruby
step :validate_file_size, ->(result) {
  filepath = result.value
  max_size = 10 * 1024 * 1024  # 10 MB

  file_size = File.size(filepath)

  if file_size > max_size
    result.halt.with_error(:size, "File too large: #{file_size} bytes (max #{max_size})")
  else
    result.with_context(:file_size, file_size).continue(filepath)
  end
}
```

## Complete File Processing Example

```ruby
class CSVProcessor
  def self.build
    SimpleFlow::Pipeline.new do
      # Validate file
      step :validate_exists, ->(result) {
        filepath = result.value
        unless File.exist?(filepath)
          return result.halt.with_error(:file, "File not found")
        end
        result.continue(filepath)
      }, depends_on: []

      step :validate_size, ->(result) {
        size = File.size(result.value)
        max_size = 50 * 1024 * 1024  # 50 MB

        if size > max_size
          return result.halt.with_error(:size, "File too large")
        end

        result.with_context(:file_size, size).continue(result.value)
      }, depends_on: [:validate_exists]

      # Read and parse
      step :read_csv, ->(result) {
        rows = CSV.read(result.value, headers: true)
        result.continue(rows.map(&:to_h))
      }, depends_on: [:validate_size]

      # Validate data
      step :validate_headers, ->(result) {
        required = ['id', 'name', 'email']
        actual = result.value.first.keys

        missing = required - actual
        if missing.any?
          return result.halt.with_error(:headers, "Missing columns: #{missing.join(', ')}")
        end

        result.continue(result.value)
      }, depends_on: [:read_csv]

      # Transform data
      step :clean_data, ->(result) {
        cleaned = result.value.map do |row|
          {
            id: row['id'].to_i,
            name: row['name'].strip.capitalize,
            email: row['email'].downcase.strip
          }
        end
        result.continue(cleaned)
      }, depends_on: [:validate_headers]

      step :filter_invalid, ->(result) {
        valid = result.value.select do |row|
          row[:email] =~ /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
        end

        invalid_count = result.value.size - valid.size
        if invalid_count > 0
          result = result.with_context(:invalid_count, invalid_count)
        end

        result.continue(valid)
      }, depends_on: [:clean_data]

      # Save results
      step :write_output, ->(result) {
        output = 'output/cleaned.json'
        File.write(output, JSON.pretty_generate(result.value))

        result
          .with_context(:output_file, output)
          .with_context(:records_written, result.value.size)
          .continue(output)
      }, depends_on: [:filter_invalid]
    end
  end
end

# Usage
result = CSVProcessor.build.call(
  SimpleFlow::Result.new('data/users.csv')
)

if result.continue?
  puts "Processed successfully:"
  puts "  File size: #{result.context[:file_size]} bytes"
  puts "  Records written: #{result.context[:records_written]}"
  puts "  Invalid records skipped: #{result.context[:invalid_count] || 0}"
  puts "  Output: #{result.context[:output_file]}"
else
  puts "Processing failed:"
  result.errors.each do |category, messages|
    puts "  #{category}: #{messages.join(', ')}"
  end
end
```

## Binary File Processing

### Reading Binary Files

```ruby
step :read_binary, ->(result) {
  filepath = result.value
  content = File.binread(filepath)

  result
    .with_context(:file_size, content.bytesize)
    .with_context(:encoding, content.encoding.name)
    .continue(content)
}
```

### Processing Images

```ruby
require 'mini_magick'

step :process_image, ->(result) {
  filepath = result.value

  image = MiniMagick::Image.open(filepath)

  # Resize if too large
  if image.width > 1920 || image.height > 1080
    image.resize '1920x1080'
  end

  # Generate thumbnail
  thumbnail = image.clone
  thumbnail.resize '200x200'

  result
    .with_context(:original_size, [image.width, image.height])
    .with_context(:thumbnail_path, filepath.gsub('.jpg', '_thumb.jpg'))
    .continue(filepath)
}
```

## Temporary Files

### Using Temporary Files

```ruby
step :use_temp_file, ->(result) {
  require 'tempfile'

  Tempfile.create(['process', '.json']) do |temp|
    # Write intermediate data
    temp.write(JSON.generate(result.value))
    temp.rewind

    # Process temp file
    processed = process_file(temp.path)

    # Temp file automatically deleted when block exits
    result.continue(processed)
  end
}
```

## Related Documentation

- [Data Fetching](data-fetching.md) - Fetching data from various sources
- [Error Handling](error-handling.md) - Error handling strategies
- [Complex Workflows](complex-workflows.md) - Building complete pipelines
- [Performance Guide](../concurrent/performance.md) - File processing optimization
