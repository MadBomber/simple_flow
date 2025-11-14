## [Unreleased]

### Fixed
- Critical bug in Result class where @continue flag was not preserved when creating new instances
- Fixed test files with incorrect require statements
- Fixed pipeline_test.rb with duplicate Result class definition
- Removed deprecated assertions in tests

### Added
- GitHub Actions CI workflow for automated testing across Ruby versions 2.7-3.3
- Comprehensive test suite for all components
- frozen_string_literal comments to all Ruby files for performance
- Proper gemspec metadata (summary, description, homepage, URLs)
- Better test coverage for StepTracker functionality

### Changed
- Updated gemspec required Ruby version to >= 2.7.0 (from >= 3.2.0) for broader compatibility
- Improved file structure and require statements in lib/simple_flow.rb
- Enhanced test reliability and maintainability

## [0.1.0] - 2025-11-13

- Initial release
