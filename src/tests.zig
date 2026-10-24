//! Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
//! SPDX-License-Identifier: MIT

const std = @import("std");
const opal = @import("opal");

const testing = std.testing;

fn fieldCount(comptime T: type) comptime_int {
    return @typeInfo(T).@"struct".field_names.len;
}

extern const opal_abi_sizes: [4]usize;
extern const opal_abi_counts: [4]usize;
extern const opal_abi_version: [4]c_int;
extern const opal_abi_queued_write_offsets: [fieldCount(opal.QueuedWrite)]usize;
extern const opal_abi_operator_offsets: [fieldCount(opal.Operator)]usize;
extern const opal_abi_channel_offsets: [fieldCount(opal.Channel)]usize;
extern const opal_abi_opal_offsets: [fieldCount(opal.Opal)]usize;

fn expectLayout(comptime T: type, c_size: usize, c_field_count: usize, c_offsets: []const usize) !void {
    const names = @typeInfo(T).@"struct".field_names;
    try testing.expectEqual(c_field_count, names.len);
    try testing.expectEqual(c_size, @sizeOf(T));
    inline for (names, 0..) |name, i| {
        try testing.expectEqual(c_offsets[i], @offsetOf(T, name));
    }
}

test "struct layouts match the C compiler" {
    try expectLayout(opal.QueuedWrite, opal_abi_sizes[0], opal_abi_counts[0], &opal_abi_queued_write_offsets);
    try expectLayout(opal.Operator, opal_abi_sizes[1], opal_abi_counts[1], &opal_abi_operator_offsets);
    try expectLayout(opal.Channel, opal_abi_sizes[2], opal_abi_counts[2], &opal_abi_channel_offsets);
    try expectLayout(opal.Opal, opal_abi_sizes[3], opal_abi_counts[3], &opal_abi_opal_offsets);
}

test "version macros match the C header" {
    try testing.expectEqual(opal_abi_version[0], opal.version_major);
    try testing.expectEqual(opal_abi_version[1], opal.version_minor);
    try testing.expectEqual(opal_abi_version[2], opal.version_patch);
    try testing.expectEqual(opal_abi_version[3], opal.version);
    try testing.expectEqual(3, opal.version_major);
    try testing.expectEqual(0, opal.version_minor);
    try testing.expectEqual(0, opal.version_patch);
    try testing.expectEqual(30000, opal.version);
}

const RegWrite = struct { reg: u16, val: u8 };

// A plain 2-op voice on channel 0: silent modulator, additive connection, so
// the carrier sine is the output. Instant attack, sustained, full volume,
// roughly 440 Hz (block 4, fnum 0x244).
const test_voice = [_]RegWrite{
    .{ .reg = 0x105, .val = 0x01 },
    .{ .reg = 0x20, .val = 0x21 },
    .{ .reg = 0x40, .val = 0x3F },
    .{ .reg = 0x60, .val = 0xF0 },
    .{ .reg = 0x80, .val = 0x0F },
    .{ .reg = 0x23, .val = 0x21 },
    .{ .reg = 0x43, .val = 0x00 },
    .{ .reg = 0x63, .val = 0xF0 },
    .{ .reg = 0x83, .val = 0x0F },
    .{ .reg = 0xC0, .val = 0x31 },
    .{ .reg = 0xA0, .val = 0x44 },
    .{ .reg = 0xB0, .val = 0x32 },
};

fn channelEnergy(frames: []const i16) struct { left: u64, right: u64 } {
    var left: u64 = 0;
    var right: u64 = 0;
    var i: usize = 0;
    while (i < frames.len) : (i += 2) {
        left += @abs(frames[i]);
        right += @abs(frames[i + 1]);
    }
    return .{ .left = left, .right = right };
}

fn peakOf(frames: []const i16) u16 {
    var peak: u16 = 0;
    for (frames) |s| peak = @max(peak, @abs(s));
    return peak;
}

test "initialized chip outputs silence" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);

    for (0..256) |_| {
        const s = chip.sample();
        try testing.expectEqual(0, s.left);
        try testing.expectEqual(0, s.right);
    }

    for (chip.op) |op| {
        try testing.expectEqual(.release, op.envelope_stage);
        try testing.expectEqual(0x1FF, op.eg_out);
        try testing.expectEqual(0, op.key);
    }
    for (chip.chan, 0..) |ch, i| {
        try testing.expectEqual(.two_op, ch.chan_type);
        try testing.expectEqual(3, ch.output_enable);
        const bank_pos = i % 9;
        if (bank_pos < 3) {
            try testing.expectEqual(i + 3, ch.pair_index);
        } else if (bank_pos < 6) {
            try testing.expectEqual(i - 3, ch.pair_index);
        } else {
            try testing.expectEqual(opal.ch_none, ch.pair_index);
        }
    }
}

test "four-operator pairing follows register 104h alone" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);

    chip.writeReg(0x105, 0x01);
    chip.writeReg(0x104, 0x01);

    try testing.expectEqual(1, chip.new_mode);
    try testing.expectEqual(1, chip.pair_enable);
    try testing.expectEqual(.four_op, chip.chan[0].chan_type);
    try testing.expectEqual(.four_op2, chip.chan[3].chan_type);
    try testing.expectEqual(3, chip.chan[0].pair_index);
    try testing.expectEqual(0, chip.chan[3].pair_index);
    try testing.expectEqual(.two_op, chip.chan[1].chan_type);
    const paired = chip.chan;

    chip.writeReg(0x105, 0x00);
    try testing.expectEqual(0, chip.new_mode);
    try testing.expectEqual(.four_op, chip.chan[0].chan_type);
    try testing.expectEqual(.four_op2, chip.chan[3].chan_type);
    try testing.expectEqual(3, chip.chan[0].pair_index);
    try testing.expectEqual(0, chip.chan[3].pair_index);

    // A C0 write recomputes the routing. The pair keeps its 4-op algorithm.
    chip.writeReg(0xC0, 0x00);
    try testing.expectEqual(paired[0], chip.chan[0]);
    try testing.expectEqual(paired[3], chip.chan[3]);

    chip.writeReg(0x104, 0x00);
    try testing.expectEqual(1, chip.pair_enable);
    try testing.expectEqual(.four_op, chip.chan[0].chan_type);

    chip.writeReg(0x105, 0x01);
    chip.writeReg(0x104, 0x00);
    try testing.expectEqual(0, chip.pair_enable);
    try testing.expectEqual(.two_op, chip.chan[0].chan_type);
    try testing.expectEqual(.two_op, chip.chan[3].chan_type);
    try testing.expectEqual(3, chip.chan[0].pair_index);
    try testing.expectEqual(0, chip.chan[3].pair_index);
}

test "clearing NEW leaves bank 1 playing" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    const bank1_voice = [_]RegWrite{
        .{ .reg = 0x105, .val = 0x01 },
        .{ .reg = 0x120, .val = 0x21 },
        .{ .reg = 0x140, .val = 0x3F },
        .{ .reg = 0x160, .val = 0xF0 },
        .{ .reg = 0x180, .val = 0x0F },
        .{ .reg = 0x123, .val = 0x21 },
        .{ .reg = 0x143, .val = 0x00 },
        .{ .reg = 0x163, .val = 0xF0 },
        .{ .reg = 0x183, .val = 0x0F },
        .{ .reg = 0x1C0, .val = 0x31 },
        .{ .reg = 0x1A0, .val = 0x44 },
        .{ .reg = 0x1B0, .val = 0x32 },
    };
    for (bank1_voice) |w| chip.writeReg(w.reg, w.val);

    try testing.expectEqual(1, chip.new_mode);
    try testing.expectEqual(1, chip.op[opal.modulatorSlot(9)].multiple);

    var frames: [4096]i16 = undefined;
    chip.render(&frames);
    try testing.expect(peakOf(&frames) > 1000);

    chip.writeReg(0x105, 0x00);
    try testing.expectEqual(0, chip.new_mode);
    try testing.expectEqual(1, chip.op[opal.modulatorSlot(9)].multiple);
    try testing.expectEqual(3, chip.chan[9].output_enable);

    chip.render(&frames);
    chip.render(&frames);
    try testing.expect(peakOf(&frames) > 1000);
}

test "bank 1 writes land in bank 0 while NEW is clear" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.writeReg(0x120, 0x0F);
    try testing.expectEqual(0, chip.new_mode);
    try testing.expectEqual(0x0F, chip.op[0].multiple);
    try testing.expectEqual(0, chip.op[opal.modulatorSlot(9)].multiple);

    chip.writeReg(0x105, 0x01);
    try testing.expectEqual(0x0F, chip.op[0].multiple);
    chip.writeReg(0x120, 0x03);
    try testing.expectEqual(0x0F, chip.op[0].multiple);
    try testing.expectEqual(3, chip.op[opal.modulatorSlot(9)].multiple);
}

test "a voice is audible without a C0 write" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| {
        if (w.reg == 0xC0) continue;
        chip.writeReg(w.reg, w.val);
    }

    try testing.expectEqual(1, chip.new_mode);
    try testing.expectEqual(3, chip.chan[0].output_enable);

    var frames: [4096]i16 = undefined;
    chip.render(&frames);
    try testing.expect(peakOf(&frames) > 1000);
}

test "C0 speaker bits apply at write time" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.writeReg(0xC0, 0x10);
    try testing.expectEqual(0, chip.new_mode);
    try testing.expectEqual(3, chip.chan[0].output_enable);

    chip.writeReg(0x105, 0x01);
    try testing.expectEqual(3, chip.chan[0].output_enable);
    chip.writeReg(0xC0, 0x10);
    try testing.expectEqual(1, chip.chan[0].output_enable);

    chip.writeReg(0x105, 0x00);
    try testing.expectEqual(1, chip.chan[0].output_enable);
}

test "waveforms above 3 are stored only while NEW is set" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.writeReg(0xE0, 0x07);
    try testing.expectEqual(0, chip.new_mode);
    try testing.expectEqual(3, chip.op[0].waveform);

    chip.writeReg(0x105, 0x01);
    try testing.expectEqual(3, chip.op[0].waveform);
    chip.writeReg(0xE0, 0x07);
    try testing.expectEqual(7, chip.op[0].waveform);

    chip.writeReg(0x105, 0x00);
    try testing.expectEqual(7, chip.op[0].waveform);
}

test "a masked timer sets nothing and a mask clears a raised flag" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.writeReg(0x02, 0xFF);
    chip.writeReg(0x04, 0x01);

    var frames: [32]i16 = undefined;
    chip.render(&frames);
    try testing.expectEqual(0xC0, chip.readStatus());

    chip.writeReg(0x04, 0x41);
    try testing.expectEqual(0, chip.readStatus());

    chip.render(&frames);
    try testing.expectEqual(0, chip.readStatus());
}

test "keyed-on voice produces audio and exposes operator state" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| chip.writeReg(w.reg, w.val);

    var frames: [8192]i16 = undefined;
    chip.render(&frames);
    try testing.expect(peakOf(&frames) > 1000);

    const carrier = &chip.op[opal.carrierSlot(0)];
    try testing.expect(carrier.key != 0);
    try testing.expect(carrier.envelope_stage != .off);
    try testing.expectEqual(opal.modulatorSlot(0), chip.chan[0].op_slot[0]);
    try testing.expectEqual(opal.carrierSlot(0), chip.chan[0].op_slot[1]);
    try testing.expectEqual(.two_op, chip.chan[0].chan_type);
}

test "a copy is a complete save state" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| chip.writeReg(w.reg, w.val);
    var warmup: [2048]i16 = undefined;
    chip.render(&warmup);

    var copy = chip.*;
    var original_frames: [2048]i16 = undefined;
    var copy_frames: [2048]i16 = undefined;
    chip.render(&original_frames);
    copy.render(&copy_frames);
    try testing.expectEqualSlices(i16, &original_frames, &copy_frames);
}

test "buffered writes match immediate writes after flush" {
    const immediate = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer immediate.destroy(testing.allocator);
    const buffered = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer buffered.destroy(testing.allocator);

    for (test_voice) |w| immediate.writeReg(w.reg, w.val);
    for (test_voice) |w| buffered.writeRegBuffered(w.reg, w.val);
    buffered.flushWriteBuf();

    var immediate_frames: [2048]i16 = undefined;
    var buffered_frames: [2048]i16 = undefined;
    immediate.render(&immediate_frames);
    buffered.render(&buffered_frames);
    try testing.expectEqualSlices(i16, &immediate_frames, &buffered_frames);
}

test "setSampleRate keeps queued writes" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.writeRegBuffered(0x20, 0x21);
    try testing.expectEqual(1, chip.queue_count);
    try testing.expectEqual(0, chip.op[0].multiple);

    chip.setSampleRate(48000);
    try testing.expectEqual(48000, chip.sample_rate);
    try testing.expectEqual(1, chip.queue_count);
    try testing.expectEqual(0, chip.op[0].multiple);

    chip.flushWriteBuf();
    try testing.expectEqual(0, chip.queue_count);
    try testing.expectEqual(1, chip.op[0].multiple);
}

test "sample rate clamps and zero or less selects the native rate" {
    const limit: i32 = std.math.maxInt(i32) - opal.opl3_sample_rate;
    var chip = opal.Opal.init(0);
    try testing.expectEqual(opal.opl3_sample_rate, chip.sample_rate);

    chip = opal.Opal.init(-1);
    try testing.expectEqual(opal.opl3_sample_rate, chip.sample_rate);

    chip.setSampleRate(44100);
    try testing.expectEqual(44100, chip.sample_rate);

    chip.setSampleRate(-1);
    try testing.expectEqual(opal.opl3_sample_rate, chip.sample_rate);

    chip.setSampleRate(limit + 1);
    try testing.expectEqual(limit, chip.sample_rate);
}

// Regression: the resampler multiplied the 16.16 fraction by the step between
// two chip samples in 32 bits. A step wider than half of full scale overflows,
// which loud OPL3 material reaches routinely. Both steps here are wide enough
// that the old code traps under UBSan and wraps without it.
test "resampler interpolates a full-scale step without overflowing" {
    const chip = try opal.Opal.create(testing.allocator, 44100);
    defer chip.destroy(testing.allocator);

    chip.sample_accum = 35281;
    chip.last_output = .{ 8734, -8734 };
    chip.curr_output = .{ -32768, 32767 };

    const s = chip.sample();
    try testing.expectEqual(-24468, s.left);
    try testing.expectEqual(24467, s.right);
    try testing.expect(s.left > chip.curr_output[0] and s.left < chip.last_output[0]);
    try testing.expect(s.right > chip.last_output[1] and s.right < chip.curr_output[1]);
}

test "pan moves output between stereo channels" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| chip.writeReg(w.reg, w.val);
    var frames: [4096]i16 = undefined;

    chip.pan(0, 0);
    chip.render(&frames);
    const hard_left = channelEnergy(&frames);
    try testing.expect(hard_left.left > hard_left.right * 4);

    chip.pan(0, 127);
    chip.render(&frames);
    const hard_right = channelEnergy(&frames);
    try testing.expect(hard_right.right > hard_right.left * 4);
}

test "pan clamps levels above 127" {
    var chip = opal.Opal.init(opal.opl3_sample_rate);
    chip.pan(0, 127);
    const left = chip.chan[0].left_pan;
    const right = chip.chan[0].right_pan;
    try testing.expect(left < right);

    chip.pan(0, 255);
    try testing.expectEqual(left, chip.chan[0].left_pan);
    try testing.expectEqual(right, chip.chan[0].right_pan);
}
