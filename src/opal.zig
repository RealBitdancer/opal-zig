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
pub const num_channels = 18;
pub const num_operators = 36;
pub const write_buf_size = 4096;
pub const write_buf_delay = 2;

/// Mirrors opal_bool, a C int. Nonzero means true.
pub const Bool = c_int;

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
/// slot + 9. Prefer the indices when copying state out of a live instance,
/// for example a visualizer snapshotting from another thread: the cross
/// pointers keep pointing into the original instance.
pub const Operator = extern struct {
    master: ?*Opal,
    chan: ?*Channel,
    slot_index: u8,
    phase: u32,
    phase_out: u16,
    phase_reset: Bool,
    waveform: u16,
    freq_mult_times2: u16,
    /// -1 off, 0 attack, 1 decay, 2 sustain, 3 release.
    envelope_stage: c_int,
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
    mod: ?*i16,
    key_scale_rate: Bool,
    sustain_mode: Bool,
    tremolo_enable: Bool,
    vibrato_enable: Bool,
};

/// A single channel, which can contain two or more operators.
pub const Channel = extern struct {
    op: [4]?*Operator,
    master: ?*Opal,
    chan_index: u8,
    chan_type: c_int,
    freq: u16,
    octave: u16,
    key_scale_number: u16,
    feedback_shift: u16,
    modulation_type: u16,
    alg: u16,
    channel_pair: ?*Channel,
    out_ptr: [4]?*i16,
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

const channel_slots = [num_channels]usize{
    0,  1,  2,  6,  7,  8,  12, 13, 14,
    18, 19, 20, 24, 25, 26, 30, 31, 32,
};

/// An emulated OPL3 chip. init wires internal cross pointers into the
/// instance itself: initialize in place and do not copy or relocate an
/// instance afterwards. After any move, call init on the new address, which
/// also resets all chip state.
pub const Opal = extern struct {
    sample_rate: i32,
    sample_accum: i32,
    last_output: [2]i16,
    curr_output: [2]i16,
    mix_buff_right: i32,
    chan: [num_channels]Channel,
    op: [num_operators]Operator,
    zero_mod: i16,
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
    note_sel: Bool,
    opl3_enabled: Bool,
    rhythm_mode: Bool,
    waveform_select: Bool,
    composite_sine_wave: Bool,
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
    write_buf_sample_cnt: u64,
    write_buf_cur: u32,
    write_buf_last: u32,
    write_buf_last_time: u64,

    /// Initialize in place at the given output sample rate. See the type
    /// documentation for the no-copy rule.
    pub fn init(self: *Opal, sample_rate_hz: i32) void {
        Opal_Init(self, @intCast(sample_rate_hz));
    }

    /// Allocate and initialize an instance. The heap address pins the
    /// instance, which satisfies the no-copy rule and keeps the sizable
    /// struct (about 70 KiB on 64-bit targets) off the stack.
    pub fn create(allocator: std.mem.Allocator, sample_rate_hz: i32) !*Opal {
        const self = try allocator.create(Opal);
        self.init(sample_rate_hz);
        return self;
    }

    pub fn destroy(self: *Opal, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    /// Change the output sample rate of an initialized instance.
    pub fn setSampleRate(self: *Opal, sample_rate_hz: i32) void {
        Opal_SetSampleRate(self, @intCast(sample_rate_hz));
    }

    /// Write a register immediately, on the same sample as the call.
    pub fn port(self: *Opal, reg: u16, value: u8) void {
        Opal_Port(self, reg, value);
    }

    /// Queue a register write. Queued writes apply write_buf_delay chip
    /// samples apart, matching real chip timing.
    pub fn portBuffered(self: *Opal, reg: u16, value: u8) void {
        Opal_PortBuffered(self, reg, value);
    }

    /// Apply any queued register writes immediately.
    pub fn flushWriteBuf(self: *Opal) void {
        Opal_FlushWriteBuf(self);
    }

    /// Set the panning level for a channel: 0 left, 64 middle, 127 right.
    /// ch is 0 to 17, or 0 to 8 with bit 8 set for the second bank.
    pub fn pan(self: *Opal, ch: u16, level: u8) void {
        Opal_Pan(self, ch, level);
    }

    /// Generate one stereo 16-bit PCM sample.
    pub fn sample(self: *Opal) StereoSample {
        var out: StereoSample = undefined;
        Opal_Sample(self, &out.left, &out.right);
        return out;
    }

    /// Fill a buffer with interleaved stereo frames (left, right, left, ...).
    /// The buffer length must be even.
    pub fn render(self: *Opal, interleaved: []i16) void {
        std.debug.assert(interleaved.len % 2 == 0);
        var i: usize = 0;
        while (i < interleaved.len) : (i += 2) {
            Opal_Sample(self, &interleaved[i], &interleaved[i + 1]);
        }
    }

    /// Read the chip status register: bit 7 IRQ, bit 6 timer 1 overflow,
    /// bit 5 timer 2 overflow. Flags stay set until a reset write (bit 7 of
    /// register 4), as on real hardware.
    pub fn read(self: *Opal) u8 {
        return Opal_Read(self);
    }
};

pub extern fn Opal_Init(self: *Opal, sample_rate: c_int) void;
pub extern fn Opal_SetSampleRate(self: *Opal, sample_rate: c_int) void;
pub extern fn Opal_Port(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn Opal_PortBuffered(self: *Opal, reg_num: u16, val: u8) void;
pub extern fn Opal_FlushWriteBuf(self: *Opal) void;
pub extern fn Opal_Pan(self: *Opal, reg_num: u16, pan: u8) void;
pub extern fn Opal_Sample(self: *Opal, left: *i16, right: *i16) void;
pub extern fn Opal_Read(self: *Opal) u8;
