//! Zig binding for opal, the OPL3 (Yamaha YMF262) and OPL2 FM synthesis
//! emulator (github.com/RealBitdancer/opal).
//!
//! Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
//! SPDX-License-Identifier: MIT
//!
//! The structs below mirror include/opal/opal.h field for field. The test
//! suite verifies every size and offset against the C compiler, so a layout
//! change upstream fails the build loudly instead of corrupting state.

const std = @import("std");

pub const version_major = 3;
pub const version_minor = 0;
pub const version_patch = 0;
pub const version = version_major * 10000 + version_minor * 100 + version_patch;

pub const opl3_sample_rate = 49716;
pub const channel_count = 18;
pub const operator_count = 36;
pub const write_buf_size = 4096;
pub const write_buf_delay = 2;

/// No operator: an index field with this value reads as silence.
pub const op_none: u8 = 0xFF;
/// Operator.mod_source only: the operator's own feedback value.
pub const mod_own_fb: u8 = 0xFE;
/// Channel cannot pair. Used on channels 6-8 and 15-17.
pub const ch_none: u8 = 0xFF;

/// Envelope generator stage of an operator. Non-exhaustive, so a value a
/// future opal release might add stays representable.
pub const EnvelopeStage = enum(c_int) {
    /// Defined for visualizers. The core never writes it: idle operators sit
    /// in `release` with `eg_out` at 511 or more.
    off = -1,
    attack = 0,
    decay = 1,
    sustain = 2,
    release = 3,
    _,
};

/// Current role of a channel. Non-exhaustive, so a value a future opal
/// release might add stays representable.
pub const ChannelType = enum(c_int) {
    /// Two-operator melodic channel.
    two_op = 0,
    /// Primary half of a four-operator pair.
    four_op = 1,
    /// Secondary half of a four-operator pair.
    four_op2 = 2,
    /// Rhythm-mode percussion channel.
    drum = 3,
    _,
};

pub const StereoSample = struct {
    left: i16,
    right: i16,
};

pub const QueuedWrite = extern struct {
    due: u64,
    reg_num: u16,
    value: u8,
};

/// One FM operator, mapping to one OPL3 slot. Melodic channel ch uses
/// op[modulatorSlot(ch)] as its modulator and op[carrierSlot(ch)] as its
/// carrier. In 4-op mode the paired channel contributes slot + 6 and
/// slot + 9. All cross references are indices into Opal.op and Opal.chan,
/// so a copied instance is fully self-contained.
pub const Operator = extern struct {
    envelope_stage: EnvelopeStage,
    /// Current total attenuation (envelope + output level + KSL + tremolo)
    /// in 0.1875 dB steps, where 0 is loudest and 511 or more is silence.
    eg_out: u16,
    /// Nonzero while keyed on: bit 0 is normal key on, bit 1 is rhythm key on.
    key: u8,
    /// Phase modulation input: an index into Opal.op whose out is read,
    /// mod_own_fb for the operator's own feedback, or op_none for none.
    mod_source: u8,
    out: i16,
    prev_out: i16,
    phase: u32,
    envelope: u16,
    tremolo: u8,
    vibrato: u8,
    sustain_hold: u8,
    key_scale_rate: u8,
    multiple: u8,
    key_scale_level: u8,
    total_level: u8,
    attack_rate: u8,
    decay_rate: u8,
    sustain_level: u8,
    release_rate: u8,
    waveform: u8,
};

/// A single channel, which can contain two or more operators. op_slot holds
/// the indices of the channel's operators in Opal.op (op_none when absent).
/// pair_index is the physical 4-op partner (0+3, 1+4, 2+5, and the same on
/// bank 1). Init pre-wires those pairs. Channels that cannot pair (6-8,
/// 15-17) use ch_none. Whether 4-op is active is chan_type, not pair_index.
/// out_source lists up to four operator indices whose out values sum into
/// the channel output, describing the active FM algorithm routing.
pub const Channel = extern struct {
    op_slot: [4]u8,
    /// Physical 4-op partner. Pre-wired on capable channels even while
    /// chan_type is two_op. ch_none only on channels that cannot pair.
    pair_index: u8,
    out_source: [4]u8,
    chan_type: ChannelType,
    left_pan: u16,
    right_pan: u16,
    f_number: u16,
    block: u8,
    latched_key_scale_number: u8,
    feedback: u8,
    connection: u8,
    /// Bit 0 is the left speaker, bit 1 the right. Init sets both.
    output_enable: u8,
    algorithm: u8,
};

/// Index into Opal.op of the modulator slot for melodic channel ch
/// (0 to 8 is bank 0, 9 to 17 is bank 1).
pub fn modulatorSlot(ch: usize) usize {
    return channel_slots[ch];
}

/// Index into Opal.op of the carrier slot for melodic channel ch.
pub fn carrierSlot(ch: usize) usize {
    return channel_slots[ch] + 3;
}

const channel_slots = [channel_count]usize{
    0,  1,  2,  6,  7,  8,  12, 13, 14,
    18, 19, 20, 24, 25, 26, 30, 31, 32,
};

/// An emulated OPL3 chip. The struct holds no pointers: all internal
/// references are indices, so an instance is a plain value. Copy, memcpy,
/// or relocate it freely. A copy is a complete save state.
pub const Opal = extern struct {
    sample_rate: i32,
    sample_accum: i32,
    last_output: [2]i16,
    curr_output: [2]i16,
    chan: [channel_count]Channel,
    op: [operator_count]Operator,
    timer: [2]u8,
    timer_control: u8,
    timer_count: [2]u16,
    status: u8,
    new_mode: u8,
    pair_enable: u8,
    rhythm_mode: u8,
    note_select: u8,
    tremolo_depth: u8,
    vibrato_depth: u8,
    wave_select_enable: u8,
    composite_sine: u8,
    tremolo_position: u8,
    tremolo_level: u8,
    sample_counter: u16,
    hi_hat_phase: u16,
    cymbal_phase: u16,
    noise: u32,
    pending_right: i32,
    chip_samples: u64,
    last_due: u64,
    queue_head: u16,
    queue_count: u16,
    queue: [write_buf_size]QueuedWrite,

    /// Return an initialized instance at the given output sample rate.
    /// Zero or a negative rate selects 49716 Hz. Rates above
    /// 2147483647 - 49716 clamp to that value.
    pub fn init(sample_rate_hz: i32) Opal {
        var self: Opal = undefined;
        opalInit(&self, @intCast(sample_rate_hz));
        return self;
    }

    /// Allocate and initialize an instance, keeping the sizable struct
    /// (about 66 KiB) off the stack.
    pub fn create(allocator: std.mem.Allocator, sample_rate_hz: i32) !*Opal {
        const self = try allocator.create(Opal);
        opalInit(self, @intCast(sample_rate_hz));
        return self;
    }

    pub fn destroy(self: *Opal, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// Change the output sample rate. The write queue is left in place.
    /// Zero or a negative rate selects 49716 Hz. Rates above
    /// 2147483647 - 49716 clamp to that value.
    pub fn setSampleRate(self: *Opal, sample_rate_hz: i32) void {
        opalSetSampleRate(self, @intCast(sample_rate_hz));
    }

    /// Write a register immediately, on the same sample as the call.
    pub fn writeReg(self: *Opal, reg: u16, value: u8) void {
        opalWriteReg(self, reg, value);
    }

    /// Queue a register write. Queued writes land at least write_buf_delay
    /// chip samples apart, so a key-off followed by a key-on still restarts
    /// the envelope. The spacing is an emulator convention, much slower than
    /// the chip's bus, so long bursts fall behind.
    pub fn writeRegBuffered(self: *Opal, reg: u16, value: u8) void {
        opalWriteRegBuffered(self, reg, value);
    }

    /// Apply any queued register writes immediately.
    pub fn flushWriteBuf(self: *Opal) void {
        opalFlushWriteBuf(self);
    }

    /// Set the panning level for a channel: 0 left, 64 middle, 127 right.
    /// Values above 127 clamp to 127. channel is 0 to 17, or 0 to 8 with
    /// bit 8 set for the second bank.
    pub fn pan(self: *Opal, channel: u16, level: u8) void {
        opalPan(self, channel, level);
    }

    /// Generate one stereo 16-bit PCM sample.
    pub fn sample(self: *Opal) StereoSample {
        var out: StereoSample = undefined;
        opalSample(self, &out.left, &out.right);
        return out;
    }

    /// Fill a buffer with interleaved stereo frames (left, right, left, ...).
    /// The buffer length must be even.
    pub fn render(self: *Opal, interleaved: []i16) void {
        std.debug.assert(interleaved.len % 2 == 0);
        var i: usize = 0;
        while (i < interleaved.len) : (i += 2) {
            opalSample(self, &interleaved[i], &interleaved[i + 1]);
        }
    }

    /// Read the chip status register: bit 7 IRQ, bit 6 timer 1 overflow,
    /// bit 5 timer 2 overflow. A flag stays set until a reset write (bit 7
    /// of register 4) or a write that sets that timer's mask bit. A masked
    /// timer sets neither its flag nor IRQ.
    pub fn readStatus(self: *Opal) u8 {
        return opalReadStatus(self);
    }
};

pub extern fn opalInit(self: *Opal, sample_rate: c_int) void;
pub extern fn opalSetSampleRate(self: *Opal, sample_rate: c_int) void;
pub extern fn opalWriteReg(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn opalWriteRegBuffered(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn opalFlushWriteBuf(self: *Opal) void;
pub extern fn opalPan(self: *Opal, channel: u16, pan: u8) void;
pub extern fn opalSample(self: *Opal, left: *i16, right: *i16) void;
pub extern fn opalReadStatus(self: *Opal) u8;
