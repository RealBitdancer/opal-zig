//! Renders a short FM arpeggio to opal-demo.wav in the working directory.
//!
//! Copyright (c) 2026 Bitdancer (github.com/RealBitdancer).
//! SPDX-License-Identifier: MIT

const std = @import("std");
const opal = @import("opal");

const sample_rate = 44100;
const gate_frames = sample_rate * 35 / 100;
const tail_frames = sample_rate * 15 / 100;
const release_frames = sample_rate / 2;

const Note = struct { block: u3, fnum: u10 };

// A minor arpeggio, roughly A4, C5, E5, A5 and back down.
const melody = [_]Note{
    .{ .block = 4, .fnum = 580 },
    .{ .block = 4, .fnum = 690 },
    .{ .block = 4, .fnum = 869 },
    .{ .block = 5, .fnum = 580 },
    .{ .block = 4, .fnum = 869 },
    .{ .block = 4, .fnum = 690 },
    .{ .block = 4, .fnum = 580 },
};

// A mild 2-op FM patch on channel 0: modulator with feedback into a full
// volume carrier, sustained envelopes.
const patch = [_][2]u16{
    .{ 0x105, 0x01 },
    .{ 0x20, 0x21 },
    .{ 0x40, 0x1A },
    .{ 0x60, 0xF5 },
    .{ 0x80, 0x37 },
    .{ 0xE0, 0x00 },
    .{ 0x23, 0x21 },
    .{ 0x43, 0x00 },
    .{ 0x63, 0xF5 },
    .{ 0x83, 0x17 },
    .{ 0xE3, 0x00 },
    .{ 0xC0, 0x38 },
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const chip = try opal.Opal.create(allocator, sample_rate);
    defer chip.destroy(allocator);

    for (patch) |w| chip.writeReg(w[0], @intCast(w[1]));

    const total_frames = melody.len * (gate_frames + tail_frames) + release_frames;
    const frames = try allocator.alloc(i16, total_frames * 2);
    defer allocator.free(frames);

    var pos: usize = 0;
    for (melody) |note| {
        const freq_hi: u8 = @intCast((@as(u16, note.block) << 2) | (note.fnum >> 8));
        chip.writeReg(0xA0, @truncate(note.fnum));
        chip.writeReg(0xB0, 0x20 | freq_hi);
        chip.render(frames[pos .. pos + gate_frames * 2]);
        pos += gate_frames * 2;
        chip.writeReg(0xB0, freq_hi);
        chip.render(frames[pos .. pos + tail_frames * 2]);
        pos += tail_frames * 2;
    }
    chip.render(frames[pos..]);

    try writeWav(init.io, "opal-demo.wav", frames, sample_rate);

    var peak: u16 = 0;
    for (frames) |s| peak = @max(peak, @abs(s));
    std.debug.print(
        "wrote opal-demo.wav: {d} stereo frames at {d} Hz, peak {d}\n",
        .{ total_frames, sample_rate, peak },
    );
}

fn writeWav(io: std.Io, path: []const u8, interleaved: []const i16, rate: u32) !void {
    const data_bytes: u32 = @intCast(interleaved.len * 2);
    var header: [44]u8 = undefined;
    header[0..4].* = "RIFF".*;
    std.mem.writeInt(u32, header[4..8], 36 + data_bytes, .little);
    header[8..12].* = "WAVE".*;
    header[12..16].* = "fmt ".*;
    std.mem.writeInt(u32, header[16..20], 16, .little);
    std.mem.writeInt(u16, header[20..22], 1, .little);
    std.mem.writeInt(u16, header[22..24], 2, .little);
    std.mem.writeInt(u32, header[24..28], rate, .little);
    std.mem.writeInt(u32, header[28..32], rate * 4, .little);
    std.mem.writeInt(u16, header[32..34], 4, .little);
    std.mem.writeInt(u16, header[34..36], 16, .little);
    header[36..40].* = "data".*;
    std.mem.writeInt(u32, header[40..44], data_bytes, .little);

    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, &header);
    try file.writeStreamingAll(io, std.mem.sliceAsBytes(interleaved));
}
