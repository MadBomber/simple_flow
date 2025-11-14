#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/simple_flow'
require 'fileutils'
require 'json'
require 'csv'

# Example: Parallel File Processing
# This example demonstrates processing multiple files in parallel,
# such as converting formats, validating data, and generating reports.

# Setup: Create sample data files
def setup_sample_files
  FileUtils.mkdir_p('tmp/input')
  FileUtils.mkdir_p('tmp/output')

  # Create sample JSON files
  3.times do |i|
    File.write("tmp/input/data_#{i + 1}.json", {
      id: i + 1,
      users: Array.new(100) { |j| { user_id: j, name: "User #{j}", active: j.even? } }
    }.to_json)
  end

  puts 'Created sample files in tmp/input/'
end

# Clean up files
def cleanup_files
  FileUtils.rm_rf('tmp')
  puts 'Cleaned up temporary files'
end

# File processing steps
def read_json_file(filename)
  JSON.parse(File.read(filename))
end

def validate_data(data)
  sleep 0.05 # Simulate validation time
  {
    total_users: data['users'].length,
    active_users: data['users'].count { |u| u['active'] },
    valid: data['users'].all? { |u| u['name'] && u['user_id'] }
  }
end

def convert_to_csv(data, output_file)
  sleep 0.05 # Simulate conversion time
  CSV.open(output_file, 'w') do |csv|
    csv << %w[user_id name active]
    data['users'].each do |user|
      csv << [user['user_id'], user['name'], user['active']]
    end
  end
  output_file
end

def generate_summary(data)
  sleep 0.05 # Simulate processing time
  {
    total: data['users'].length,
    active: data['users'].count { |u| u['active'] },
    inactive: data['users'].count { |u| !u['active'] }
  }
end

# Build the file processing pipeline
def build_pipeline
  SimpleFlow::Pipeline.new do
    # Validate input directory
    step ->(result) {
      files = result.value
      if files.empty?
        result.halt([]).with_error(:input, 'No files to process')
      else
        result.continue(files)
      end
    }

    # Process each file in parallel
    step ->(result) {
      files = result.value
      processed = []

      files.each_with_index do |filename, idx|
        # Create a sub-pipeline for each file
        file_pipeline = SimpleFlow::Pipeline.new do
          step ->(r) { r.continue(read_json_file(r.value)) }

          # Run validation, conversion, and summary in parallel
          parallel do
            step ->(r) {
              validation = validate_data(r.value)
              r.with_context(:"file_#{idx}_validation", validation).continue(r.value)
            }

            step ->(r) {
              output_file = "tmp/output/data_#{idx + 1}.csv"
              convert_to_csv(r.value, output_file)
              r.with_context(:"file_#{idx}_csv", output_file).continue(r.value)
            }

            step ->(r) {
              summary = generate_summary(r.value)
              r.with_context(:"file_#{idx}_summary", summary).continue(r.value)
            }
          end
        end

        file_result = file_pipeline.call(SimpleFlow::Result.new(filename))
        processed << file_result
      end

      # Merge all file results
      merged_context = processed.reduce({}) { |acc, r| acc.merge(r.context) }
      result.continue(processed).tap do |r|
        merged_context.each { |k, v| r.instance_variable_set(:@context, r.context.merge(k => v)) }
      end
    }

    # Generate final report
    step ->(result) {
      total_files = result.value.length
      total_valid = result.value.count { |r| r.context.values.any? { |v| v.is_a?(Hash) && v[:valid] } }

      report = {
        processed_files: total_files,
        valid_files: total_valid,
        total_users: result.context.values.sum { |v| v.is_a?(Hash) && v[:total] ? v[:total] : 0 },
        csv_files: result.context.values.select { |v| v.is_a?(String) && v.end_with?('.csv') }
      }

      result.continue(report)
    }
  end
end

# Run the example
begin
  puts '=' * 70
  puts 'SimpleFlow: Parallel File Processing Example'
  puts '=' * 70
  puts

  setup_sample_files
  puts

  input_files = Dir.glob('tmp/input/*.json')
  puts "Found #{input_files.length} files to process"
  puts

  puts 'Processing files in parallel...'
  start_time = Time.now

  pipeline = build_pipeline
  result = pipeline.call(SimpleFlow::Result.new(input_files))

  elapsed = Time.now - start_time

  if result.continue?
    puts "\n✓ Processing completed in #{elapsed.round(2)}s"
    puts "\nResults:"
    puts "  Processed files: #{result.value[:processed_files]}"
    puts "  Valid files: #{result.value[:valid_files]}"
    puts "  Total users: #{result.value[:total_users]}"
    puts "  Generated CSV files: #{result.value[:csv_files].length}"
    puts "\nCSV files created:"
    result.value[:csv_files].each { |f| puts "  - #{f}" }
  else
    puts "\n✗ Processing failed"
    puts "Errors: #{result.errors}"
  end

  puts "\n" + '=' * 70
  puts "Note: Each file was processed with parallel validation, conversion, and summary"
  puts '=' * 70
ensure
  puts "\nCleaning up..."
  cleanup_files
end
