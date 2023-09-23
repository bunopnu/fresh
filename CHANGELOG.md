# Changelog

This changelog documents all noteworthy changes in the project. The format adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) and is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Next (v0.4.0)

### Added

- Exponential backoff strategy for reconnection attempts.

### Changed

- Enhanced documentation for a more user-friendly experience.

## v0.3.0 - 22nd September 2023

### Added

- Introduced `{:close, code, reason, state}` response for the generic callback, simplifying the process of sending a close frame to the server.
- Added the `:info_logging` option, allowing you to toggle information messages.

### Changed

- Now, disconnection messages are logged as information.

## v0.2.1 - 17th September 2023

### Added

- Introduced the `close/3` function for easier sending of close frames.

## v0.2.0 - 14th September 2023

### Added

- Implemented the `handle_terminate/2` callback for handling process termination.

### Fixed

- Addressed minor documentation issues.

## v0.1.1 - 12th September 2023

### Fixed

- Added a queue for incoming messages while the websocket is `nil`.

## v0.1.0 - 11th September 2023

### Added

- Included the missing `start/1` for the `__using__/1` macro.

## v0.1.0-rc - 9th September 2023

- Initial release of Fresh.
