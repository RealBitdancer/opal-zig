# opal-zig

[![Test](https://github.com/RealBitdancer/opal-zig/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/RealBitdancer/opal-zig/actions/workflows/test.yml)

Zig binding for [opal](https://github.com/RealBitdancer/opal), the OPL3 (Yamaha YMF262)
and OPL2 FM synthesis emulator. The binding compiles the upstream C11 core with the Zig
build system and exposes it as a native Zig module. There is no code generation step and
no dependency beyond libc.

The version is the bound opal release plus a packaging revision. This is version
1.0.2-1, binding opal 1.0.2. A binding-only fix bumps the revision, a new opal release
resets it.

Design decisions that shape the public API live in [doc/design.md](doc/design.md).

## Requirements

- Zig 0.16.0 or newer.

## Installation

Add the dependency:

```sh
zig fetch --save git+https://github.com/RealBitdancer/opal-zig#v1.0.2-1
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

var chip = try opal.Opal.create(allocator, 44100);
defer chip.destroy(allocator);

chip.port(0x105, 0x01); // OPL3 mode
// ... program a voice, key on a note ...

var frames: [2048]i16 = undefined; // interleaved stereo
chip.render(&frames);
```

One rule carries over from C, and it is the only one that can hurt you: `Opal_Init` wires
internal pointers into the instance's own address, so an instance must not be copied or
relocated after initialization. `Opal.create` sidesteps the matter by pinning the roughly
70 KiB instance to a heap address. If you place an instance yourself, call `init` on its
final address and leave it there.

## API

The eight C functions map to methods on `opal.Opal`:

| C                    | Zig                            |
| :------------------- | :----------------------------- |
| `Opal_Init`          | `Opal.init`, or `Opal.create`  |
| `Opal_SetSampleRate` | `Opal.setSampleRate`           |
| `Opal_Port`          | `Opal.port`                    |
| `Opal_PortBuffered`  | `Opal.portBuffered`            |
| `Opal_FlushWriteBuf` | `Opal.flushWriteBuf`           |
| `Opal_Pan`           | `Opal.pan`                     |
| `Opal_Sample`        | `Opal.sample`, `Opal.render`   |
| `Opal_Read`          | `Opal.read`                    |

`Opal.render` is a convenience over `Opal_Sample` that fills a buffer of interleaved
stereo frames. The raw `Opal_*` functions are also exported for direct use.

The structs (`Opal`, `Channel`, `Operator`, `WriteBuf`) are mirrored as `extern struct`
with snake_case field names, so state useful to visualizers (`envelope_stage`, `eg_out`,
`key`) is readable directly. `modulatorSlot(ch)` and `carrierSlot(ch)` return the operator
indices for a melodic channel, as documented in the upstream header. The test suite
verifies every field offset and struct size against the C compiler, so the mirrors cannot
drift silently.

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
init, tone generation, buffered write equivalence, and pan.

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
