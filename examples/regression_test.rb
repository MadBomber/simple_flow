#!/usr/bin/env ruby
# frozen_string_literal: true

# Regression Test Runner
# Runs all example scripts and saves their output to regression_test/ directory
# for comparison purposes.

require 'fileutils'

class RegressionTestRunner
  EXAMPLES_DIR = File.dirname(__FILE__)
  OUTPUT_DIR = File.join(EXAMPLES_DIR, 'regression_test')

  def initialize
    @examples = Dir.glob(File.join(EXAMPLES_DIR, '*.rb'))
                   .reject { |f| File.basename(f) == 'regression_test.rb' }
                   .sort
  end

  def run
    puts "Regression Test Runner"
    puts "=" * 60
    puts "Output directory: #{OUTPUT_DIR}"
    puts "Found #{@examples.size} example files"
    puts

    ensure_output_directory

    results = @examples.map { |example| run_example(example) }

    print_summary(results)
  end

  private

  def ensure_output_directory
    FileUtils.mkdir_p(OUTPUT_DIR) unless Dir.exist?(OUTPUT_DIR)
  end

  def run_example(example_path)
    basename = File.basename(example_path, '.rb')
    output_path = File.join(OUTPUT_DIR, "#{basename}.txt")

    print "Running #{basename}... "

    start_time = Time.now
    output, status = capture_output(example_path)
    elapsed = Time.now - start_time

    File.write(output_path, output)

    if status.success?
      puts "OK (#{format('%.2f', elapsed)}s) -> #{File.basename(output_path)}"
      { name: basename, success: true, elapsed: elapsed, output_path: output_path }
    else
      puts "FAILED (exit code: #{status.exitstatus})"
      { name: basename, success: false, elapsed: elapsed, output_path: output_path, exit_code: status.exitstatus }
    end
  end

  def capture_output(example_path)
    output = `cd #{EXAMPLES_DIR} && ruby #{File.basename(example_path)} 2>&1`
    [output, $?]
  end

  def print_summary(results)
    puts
    puts "=" * 60
    puts "SUMMARY"
    puts "=" * 60

    successful = results.count { |r| r[:success] }
    failed = results.count { |r| !r[:success] }
    total_time = results.sum { |r| r[:elapsed] }

    puts "Total examples: #{results.size}"
    puts "Successful: #{successful}"
    puts "Failed: #{failed}"
    puts "Total time: #{format('%.2f', total_time)}s"
    puts

    if failed > 0
      puts "Failed examples:"
      results.reject { |r| r[:success] }.each do |result|
        puts "  - #{result[:name]} (exit code: #{result[:exit_code]})"
      end
      puts
    end

    puts "Output files saved to: #{OUTPUT_DIR}/"
    puts

    # List generated files
    puts "Generated files:"
    results.each do |result|
      file_size = File.size(result[:output_path])
      puts "  #{File.basename(result[:output_path])} (#{file_size} bytes)"
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  runner = RegressionTestRunner.new
  runner.run
end
