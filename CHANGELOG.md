# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] - 2023-09-22

### Added

- `{:close, code, reason, state}` Response for generic callback, allowing you to send close frame to the server easier.
- `:info_logging` Option to toggle information message(s).

### Changed

- Disconnection message is now logged as information.

## [0.2.1] - 2023-09-17

### Added

- `close/3` Function for sending close frame easier.

## [0.2.0] - 2023-09-14

### Added

- `handle_terminate/2` Callback for process termination.

### Fixed

- Minor documentation issues.

## [0.1.1] - 2023-09-12

### Fixed

- Add queue for incoming messages while websocket is `nil`.

## [0.1.0] - 2023-09-11

### Added

- Missing `start/1` for `__using__/1` macro.

## [0.1.0-rc] - 2023-09-09

- Initial release of Fresh.
