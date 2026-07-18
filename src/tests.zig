//! Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
//! SPDX-License-Identifier: MIT

const std = @import("std");
const opal = @import("opal");

const testing = std.testing;

extern const opal_abi_sizes: [4]usize;
extern const opal_abi_counts: [4]usize;
extern const opal_abi_write_buf_offsets: [std.meta.fields(opal.WriteBuf).len]usize;
extern const opal_abi_operator_offsets: [std.meta.fields(opal.Operator).len]usize;
extern const opal_abi_channel_offsets: [std.meta.fields(opal.Channel).len]usize;
extern const opal_abi_opal_offsets: [std.meta.fields(opal.Opal).len]usize;

fn expectLayout(comptime T: type, c_size: usize, c_field_count: usize, c_offsets: []const usize) !void {
    try testing.expectEqual(c_field_count, std.meta.fields(T).len);
    try testing.expectEqual(c_size, @sizeOf(T));
    inline for (std.meta.fields(T), 0..) |field, i| {
        try testing.expectEqual(c_offsets[i], @offsetOf(T, field.name));
    }
}

test "struct layouts match the C compiler" {
    try expectLayout(opal.WriteBuf, opal_abi_sizes[0], opal_abi_counts[0], &opal_abi_write_buf_offsets);
    try expectLayout(opal.Operator, opal_abi_sizes[1], opal_abi_counts[1], &opal_abi_operator_offsets);
    try expectLayout(opal.Channel, opal_abi_sizes[2], opal_abi_counts[2], &opal_abi_channel_offsets);
    try expectLayout(opal.Opal, opal_abi_sizes[3], opal_abi_counts[3], &opal_abi_opal_offsets);
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

test "initialized chip outputs silence" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (0..256) |_| {
        const s = chip.sample();
        try testing.expectEqual(0, s.left);
        try testing.expectEqual(0, s.right);
    }
}

test "keyed-on voice produces audio and exposes operator state" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| chip.port(w.reg, w.val);

    var frames: [8192]i16 = undefined;
    chip.render(&frames);

    var peak: u16 = 0;
    for (frames) |s| peak = @max(peak, @abs(s));
    try testing.expect(peak > 1000);

    const carrier = &chip.op[opal.carrierSlot(0)];
    try testing.expect(carrier.key != 0);
    try testing.expect(carrier.envelope_stage >= 0);
    try testing.expectEqual(&chip.op[opal.modulatorSlot(0)], chip.chan[0].op[0].?);
    try testing.expectEqual(carrier, chip.chan[0].op[1].?);
}

test "buffered writes match immediate writes after flush" {
    const immediate = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer immediate.destroy(testing.allocator);
    const buffered = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer buffered.destroy(testing.allocator);

    for (test_voice) |w| immediate.port(w.reg, w.val);
    for (test_voice) |w| buffered.portBuffered(w.reg, w.val);
    buffered.flushWriteBuf();

    var immediate_frames: [2048]i16 = undefined;
    var buffered_frames: [2048]i16 = undefined;
    immediate.render(&immediate_frames);
    buffered.render(&buffered_frames);
    try testing.expectEqualSlices(i16, &immediate_frames, &buffered_frames);
}

test "pan moves output between stereo channels" {
    const chip = try opal.Opal.create(testing.allocator, opal.opl3_sample_rate);
    defer chip.destroy(testing.allocator);

    for (test_voice) |w| chip.port(w.reg, w.val);
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
