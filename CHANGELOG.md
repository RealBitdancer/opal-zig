# Changelog

All notable changes to this binding are documented here. The version is the bound opal
release plus a packaging revision, so `1.0.2-1` is the first release binding opal
`1.0.2`.

## [1.0.2-1] - 2026-07-18

### Added

- First release, binding opal 1.0.2.
- The `opal` module compiles the upstream C11 core from the pinned release tarball with
  the Zig build system. No code generation step, no dependency beyond libc.
- `Opal`, `Channel`, `Operator`, and `WriteBuf` mirrored as `extern struct` with
  snake_case field names. The test suite verifies every struct size and field offset
  against the C compiler, so layout drift fails loudly.
- Methods wrapping the eight C functions (`init`, `setSampleRate`, `port`,
  `portBuffered`, `flushWriteBuf`, `pan`, `sample`, `read`), plus `create` and
  `destroy` to heap-pin an instance under the C core's no-copy rule, and `render` to
  fill interleaved stereo buffers.
- `modulatorSlot` and `carrierSlot` helpers matching the channel-to-slot table
  documented in the upstream header.
- A demo (`zig build run`) that renders a short FM arpeggio to `opal-demo.wav`.
