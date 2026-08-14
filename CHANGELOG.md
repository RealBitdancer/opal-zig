# Changelog

All notable changes to this binding are documented here. The version is the bound opal
release plus a packaging revision, so `1.0.2-1` is the first release binding opal
`1.0.2`.

## [2.0.2-1] - 2026-08-13

### Changed

- Binds opal 2.0.2. NEW (register 105h bit 0) is a live mode bit: bank 1, waveforms
  4-7, CHA and CHB, and four-operator pairing apply only while it is set. Disabling
  4-op no longer clears `pair_index`. That field is the physical partner, or `ch_none`
  for channels that cannot pair. `chan_type` says whether 4-op is active. `init` now
  sets every operator's `eg_out` to 0x1FF, so a snapshot taken before the first sample
  is silent. A masked timer overflow now sets FT1 or FT2. IRQ (bit 7) is set only when
  that timer is unmasked.

### Added

- `version_major`, `version_minor`, `version_patch`, and the packed `version`
  (`major * 10000 + minor * 100 + patch`), matching the `OPAL_VERSION_*` macros in
  `opal.h`.
- Tests for the 2.0.2 core fixes: pair-index wiring, NEW as a live mode bit, silence
  after enabling OPL3 without writing C0, stored waveforms 4-7 while NEW is clear,
  and a masked timer overflow that must still raise FT1.

### Fixed

- The `pair_index` field comment said it was `ch_none` when 4-op was off. Init
  pre-wires the physical partners, so a visualizer that treated a nonzero `pair_index`
  as "4-op is on" would misread every capable channel after `init`.

## [2.0.1-1] - 2026-07-25

### Changed

- Binds opal 2.0.1, which fixes a 32-bit signed overflow in the output resampler.
  The overflow was reachable whenever a track swings more than half of full scale
  between two consecutive chip samples, and it aborted the process outright under
  any toolchain that traps on signed overflow, which includes Zig's ReleaseSafe.

### Added

- A regression test that drives the resampler across a full-scale step, the case
  that used to overflow, and pins the interpolated result.

## [2.0.0-1] - 2026-07-18

### Changed

- Binds opal 2.0.0. Rendered output is bit-identical to 1.0.2, only the API shape
  changed.
- An `Opal` instance is now a plain value: upstream replaced every internal pointer
  with an index, so copying, assigning, or relocating an instance is legal and a copy
  is a complete save state. The no-copy rule is gone.
- `Opal.init` returns the instance by value. `create` and `destroy` remain as heap
  helpers for the roughly 70 KiB struct.
- Methods follow the upstream renames: `port` is now `writeReg`, `portBuffered` is
  `writeRegBuffered`, `read` is `readStatus`. The raw externs are `opalInit`,
  `opalWriteReg`, and so on.
- Constants follow the upstream renames: `num_channels` is now `channel_count` and
  `num_operators` is `operator_count`.
- Struct mirrors follow the new pointer-free layout: `op_slot`, `chan_index`,
  `mod_source`, `pair_index`, and `out_source` are index fields, boolean fields are
  `bool`, and `Opal.zero_mod` is gone.

### Added

- `EnvelopeStage` and `ChannelType`, non-exhaustive `enum(c_int)` types for the
  `envelope_stage` and `chan_type` fields.
- Index sentinels `op_none`, `mod_own_fb`, and `ch_none`.
- A save-state test: a copied chip renders the same audio as the original.

### Removed

- The `Bool` alias for `opal_bool`, which upstream removed in favor of C11 `bool`.
- The optional cross-pointer fields (`master`, `chan`, `mod`, `channel_pair`,
  `out_ptr`), replaced by the index fields above.

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
