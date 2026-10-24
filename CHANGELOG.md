# Changelog

All notable changes to this binding are documented here. The version is the bound opal
release plus a packaging revision, so `1.0.2-1` is the first release binding opal
`1.0.2`.

## [3.0.0-1] - 2026-10-24

### Changed

- Requires Zig 0.17.0.
- Binds opal 3.0.0. The emulation core is new. The eight functions keep their
  names and signatures. Rendered output is not bit-identical to 2.0.2.
- Struct mirrors follow the new layout. The visualizer fields keep their names and
  meaning: `envelope_stage`, `eg_out`, `key`, `mod_source`, and `out` in `Operator`,
  and `op_slot`, `pair_index`, `out_source`, `chan_type`, `left_pan`, and `right_pan`
  in `Channel`. Other fields may be renamed, retyped, or rescaled. `WriteBuf` is now
  `QueuedWrite` (`due`, `reg_num`, `value`). `output_enable` replaces the old
  per-speaker flags. `Opal.opl3_enabled` is now `new_mode`. `sample_counter`
  replaces `chip_timer`. `tremolo_depth` and `vibrato_depth` hold the BDh bits that
  `tremolo_shift` and `vib_shift` encoded as shifts. `hi_hat_phase` and
  `cymbal_phase` hold the phases that the `rm_*` bits sampled. The write-buffer
  cursors are `queue`, `queue_head`, `queue_count`, `chip_samples`, and `last_due`.
  Fields that used to be `bool` are `u8`, because the header stores them as
  `uint8_t`.
- Operator and channel register fields hold raw register values. `sustain_level`
  keeps its name but is now 0-15 instead of a scaled level, so code that reads it
  still compiles and gets different numbers. `total_level`, `multiple`, `feedback`,
  `f_number`, and `block` replace `output_level`, `freq_mult_times2`,
  `feedback_shift`, `freq`, and `octave`. `algorithm` replaces `alg` with a new
  encoding. The envelope rates and `waveform` are `u8`.
- NEW (register 105h bit 0) still gates new writes. While it is clear, bank 1
  writes other than 105h land in bank 0, waveforms stay in 0-3, and a C0h write
  turns on both speakers. Changing NEW no longer rewrites stored state. All 18
  channels keep playing, and four-operator pairs follow register 104h alone.
- A masked timer sets nothing. Setting a timer's mask bit clears a flag that is
  already set. IRQ stays set only while a flag is set.
- `init` and `setSampleRate` treat a rate of 0 or less as 49716 Hz and clamp
  anything above 2147483647 - 49716. `setSampleRate` no longer clears the write
  queue or the output history, so a queued write survives it. It still resets the
  resampler phase in `sample_accum`. `pan` clamps a level above 127.
- `init` still leaves every operator in `release` with `eg_out` at 0x1FF. It now
  enables both speakers on every channel, so a voice is audible without a C0
  write. The instance is about 66 KiB.

### Added

- Tests for the 3.0.0 behavior: NEW leaves stored state alone, bank 1 writes and
  waveforms 4-7 apply only while NEW is set, four-operator pairing stays after
  NEW is cleared, masked timers, sample-rate clamping, the write queue surviving
  `setSampleRate`, and pan clamping.

### Removed

- `Operator.slot_index`, `Operator.chan_index`, and `Channel.chan_index`. `op_slot`,
  `modulatorSlot`, and `carrierSlot` map channels to operators.
- Internal state that upstream dropped, including `phase_out`, `phase_reset`,
  `eg_ksl`, `fb_mod`, `chc`, `chd`, `vib_pos`, the `eg_*` envelope timer fields, and
  `rhythm_reg`.

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
