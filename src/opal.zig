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

pub const opl3_sample_rate = 49716;
pub const channel_count = 18;
pub const operator_count = 36;
pub const write_buf_size = 4096;
pub const write_buf_delay = 2;

/// No operator: an index field with this value reads as silence.
pub const op_none: u8 = 0xFF;
/// Operator.mod_source only: the operator's own feedback value.
pub const mod_own_fb: u8 = 0xFE;
/// No paired channel.
pub const ch_none: u8 = 0xFF;

/// Envelope generator stage of an operator. Non-exhaustive, so a value a
/// future opal release might add stays representable.
pub const EnvelopeStage = enum(c_int) {
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

pub const WriteBuf = extern struct {
    time: u64,
    reg: u16,
    data: u8,
};

/// One FM operator, mapping to one OPL3 slot. Melodic channel ch uses
/// op[modulatorSlot(ch)] as its modulator and op[carrierSlot(ch)] as its
/// carrier. In 4-op mode the paired channel contributes slot + 6 and
/// slot + 9. All cross references are indices into Opal.op and Opal.chan,
/// so a copied instance is fully self-contained.
pub const Operator = extern struct {
    slot_index: u8,
    chan_index: u8,
    /// Phase modulation input: an index into Opal.op whose out is read,
    /// mod_own_fb for the operator's own feedback, or op_none for none.
    mod_source: u8,
    phase: u32,
    phase_out: u16,
    phase_reset: bool,
    waveform: u16,
    freq_mult_times2: u16,
    envelope_stage: EnvelopeStage,
    envelope_level: u16,
    /// Current total attenuation (envelope + output level + KSL + tremolo)
    /// in 0.1875 dB steps, where 0 is loudest and 511 or more is silence.
    eg_out: u16,
    eg_ksl: u8,
    output_level: u16,
    attack_rate: u16,
    decay_rate: u16,
    sustain_level: u16,
    release_rate: u16,
    key_scale_reg: u8,
    /// Nonzero while keyed on: bit 0 is normal key on, bit 1 is rhythm key on.
    key: u8,
    out: i16,
    prev_out: i16,
    fb_mod: i16,
    key_scale_rate: bool,
    sustain_mode: bool,
    tremolo_enable: bool,
    vibrato_enable: bool,
};

/// A single channel, which can contain two or more operators. op_slot holds
/// the indices of the channel's operators in Opal.op (op_none when absent).
/// pair_index is the partner channel in 4-op mode (ch_none when unpaired).
/// out_source lists up to four operator indices whose out values sum into
/// the channel output, describing the active FM algorithm routing.
pub const Channel = extern struct {
    op_slot: [4]u8,
    chan_index: u8,
    pair_index: u8,
    out_source: [4]u8,
    chan_type: ChannelType,
    freq: u16,
    octave: u16,
    key_scale_number: u16,
    feedback_shift: u16,
    modulation_type: u16,
    alg: u16,
    cha: u16,
    chb: u16,
    chc: u16,
    chd: u16,
    left_pan: u16,
    right_pan: u16,
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
    mix_buff_right: i32,
    chan: [channel_count]Channel,
    op: [operator_count]Operator,
    chip_timer: u16,
    tremolo_pos: u8,
    tremolo_level: u8,
    tremolo_shift: u8,
    vib_pos: u8,
    vib_shift: u8,
    eg_timer: u64,
    eg_state: u8,
    eg_add: u8,
    eg_timer_lo: u8,
    eg_timer_rem: u8,
    note_sel: bool,
    opl3_enabled: bool,
    rhythm_mode: bool,
    waveform_select: bool,
    composite_sine_wave: bool,
    noise: u32,
    rm_hh_bit2: u8,
    rm_hh_bit3: u8,
    rm_hh_bit7: u8,
    rm_hh_bit8: u8,
    rm_tc_bit3: u8,
    rm_tc_bit5: u8,
    rhythm_reg: u8,
    timer: [2]u8,
    timer_control: u8,
    timer_count: [2]u16,
    status: u8,
    write_buf: [write_buf_size]WriteBuf,
    write_buf_sample_count: u64,
    write_buf_cur: u32,
    write_buf_last: u32,
    write_buf_last_time: u64,

    /// Return an initialized instance at the given output sample rate.
    pub fn init(sample_rate_hz: i32) Opal {
        var self: Opal = undefined;
        opalInit(&self, @intCast(sample_rate_hz));
        return self;
    }

    /// Allocate and initialize an instance, keeping the sizable struct
    /// (about 70 KiB) off the stack.
    pub fn create(allocator: std.mem.Allocator, sample_rate_hz: i32) !*Opal {
        const self = try allocator.create(Opal);
        opalInit(self, @intCast(sample_rate_hz));
        return self;
    }

    pub fn destroy(self: *Opal, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// Change the output sample rate of an initialized instance.
    pub fn setSampleRate(self: *Opal, sample_rate_hz: i32) void {
        opalSetSampleRate(self, @intCast(sample_rate_hz));
    }

    /// Write a register immediately, on the same sample as the call.
    pub fn writeReg(self: *Opal, reg: u16, value: u8) void {
        opalWriteReg(self, reg, value);
    }

    /// Queue a register write. Queued writes apply write_buf_delay chip
    /// samples apart, matching real chip timing.
    pub fn writeRegBuffered(self: *Opal, reg: u16, value: u8) void {
        opalWriteRegBuffered(self, reg, value);
    }

    /// Apply any queued register writes immediately.
    pub fn flushWriteBuf(self: *Opal) void {
        opalFlushWriteBuf(self);
    }

    /// Set the panning level for a channel: 0 left, 64 middle, 127 right.
    /// ch is 0 to 17, or 0 to 8 with bit 8 set for the second bank.
    pub fn pan(self: *Opal, ch: u16, level: u8) void {
        opalPan(self, ch, level);
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
    /// bit 5 timer 2 overflow. Flags stay set until a reset write (bit 7 of
    /// register 4), as on real hardware.
    pub fn readStatus(self: *Opal) u8 {
        return opalReadStatus(self);
    }
};

pub extern fn opalInit(self: *Opal, sample_rate: c_int) void;
pub extern fn opalSetSampleRate(self: *Opal, sample_rate: c_int) void;
pub extern fn opalWriteReg(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn opalWriteRegBuffered(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn opalFlushWriteBuf(self: *Opal) void;
pub extern fn opalPan(self: *Opal, reg_num: u16, pan: u8) void;
pub extern fn opalSample(self: *Opal, left: *i16, right: *i16) void;
pub extern fn opalReadStatus(self: *Opal) u8;
