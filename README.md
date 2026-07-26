# opal-zig

[![Test](https://github.com/RealBitdancer/opal-zig/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/RealBitdancer/opal-zig/actions/workflows/test.yml)

Zig binding for [opal](https://github.com/RealBitdancer/opal), the OPL3 (Yamaha YMF262)
and OPL2 FM synthesis emulator. The binding compiles the upstream C11 core with the Zig
build system and exposes it as a native Zig module. There is no code generation step and
no dependency beyond libc.

The version is the bound opal release plus a packaging revision. This is version
2.0.1-1, binding opal 2.0.1. A binding-only fix bumps the revision, a new opal release
resets it.

Design decisions that shape the public API live in [doc/design.md](doc/design.md).

## Requirements

- Zig 0.16.0 or newer.

## Installation

Add the dependency:

```sh
zig fetch --save git+https://github.com/RealBitdancer/opal-zig#v2.0.1-1
```

Wire it into your `build.zig`:

```zig
const opal_dep = b.dependency("opal", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("opal", opal_dep.module("opal"));
```

## Usage

```zig
const opal = @import("opal");

var chip = opal.Opal.init(44100);

chip.writeReg(0x105, 0x01); // OPL3 mode
// ... program a voice, key on a note ...

var frames: [2048]i16 = undefined; // interleaved stereo
chip.render(&frames);
```

An `Opal` instance is a plain value with no internal pointers. Copy, assign, or
relocate it freely: a copy is a complete save state. The struct is about 70 KiB, so
`Opal.create(allocator, rate)` and `destroy` are provided to keep it off the stack.

## API

The eight C functions map to methods on `opal.Opal`:

| C                      | Zig                           |
| :--------------------- | :---------------------------- |
| `opalInit`             | `Opal.init`, or `Opal.create` |
| `opalSetSampleRate`    | `Opal.setSampleRate`          |
| `opalWriteReg`         | `Opal.writeReg`               |
| `opalWriteRegBuffered` | `Opal.writeRegBuffered`       |
| `opalFlushWriteBuf`    | `Opal.flushWriteBuf`          |
| `opalPan`              | `Opal.pan`                    |
| `opalSample`           | `Opal.sample`, `Opal.render`  |
| `opalReadStatus`       | `Opal.readStatus`             |

`Opal.render` is a convenience over `opalSample` that fills a buffer of interleaved
stereo frames. The raw `opal*` functions are also exported for direct use.

The structs (`Opal`, `Channel`, `Operator`, `WriteBuf`) are mirrored as `extern struct`
with snake_case field names, so state useful to visualizers (`envelope_stage`, `eg_out`,
`key`) is readable directly. `envelope_stage` and `chan_type` are typed as the
non-exhaustive enums `EnvelopeStage` and `ChannelType`. Cross references between the
structs are indices (`op_slot`, `mod_source`, `pair_index`, `out_source`) with the
sentinels `op_none`, `mod_own_fb`, and `ch_none`, which is what makes a copied instance
self-contained. `modulatorSlot(ch)` and `carrierSlot(ch)` return the operator indices
for a melodic channel, as documented in the upstream header. The test suite verifies
every field offset and struct size against the C compiler, so the mirrors cannot drift
silently.

## Demo

```sh
zig build run
```

renders a short FM arpeggio to `opal-demo.wav` in the working directory.

## Tests

```sh
zig build test
```

runs layout verification against the C compiler plus behavioral tests: silence after
init, tone generation, save-state copies, buffered write equivalence, and pan.

## Updating the bound opal release

1. Point `opal_c` in `build.zig.zon` at the new tag URL and hash.
2. Run `zig build test`.
3. If the layout test fails, update the mirrored structs in `src/opal.zig` and the offset
   tables in `src/abi_check.c` together.
4. Set this package's `.version` to the new opal version with revision `-1` and
   refresh this README.
5. Add a CHANGELOG.md section for the new version. Pushing the `v<version>` tag
   creates the GitHub release with that section as its notes.

## License

MIT, see [LICENSE](LICENSE). The underlying Opal core is public domain, and the C11 port
is MIT. See the [upstream repository](https://github.com/RealBitdancer/opal) for details.
