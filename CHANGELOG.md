# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project aims to adhere to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added <!-- for new features. -->

### Changed <!-- for changes in existing functionality. -->

### Deprecated <!-- for soon-to-be removed features. -->

### Removed <!-- for now removed features. -->

### Fixed <!-- for any bug fixes. -->

## [1.1.0] - 2023-05-12

### Removed

- Remove support for Rails < 6

### Fixed

- Fixes demo mode initializer on Rails 7

## [1.0.3] - 2022-08-15

### Fixed

- Fixes rubygems release of the gem so that the `db/migrate` folder is actually
  present.

## [1.0.2] - 2022-08-15

### Fixed

- Fixes `demo_mode:install` generator, which was failing to find
  `demo_mode:install:migrations` task on newer Rails versions.

## [1.0.1] - 2022-06-03

### Fixed

- Always register demo_mode assets for precompilation, regardless of `Rails.env`.

## [1.0.0] - 2022-05-10

### Added

- Initial release!

[1.0.2]: https://github.com/betterment/demo_mode/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/betterment/demo_mode/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/betterment/demo_mode/releases/tag/v1.0.0
