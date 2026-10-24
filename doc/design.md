# Design decisions

## Hand-written `extern struct` mirrors

The public C API is eight functions plus four structs whose layout is part of the
contract (visualizers read operator and channel fields). The binding mirrors those
structs by hand with snake_case field names instead of using `@cImport`.

Reasons:

- Typed, stable Zig field names without a translate-c dependency.
- Layout drift fails loudly: `src/abi_check.c` exports sizes and offsets from the C
  compiler, and `src/tests.zig` compares them to every Zig field.

Trade-off: on each upstream struct change, update the Zig fields and the C offset
tables together. The ABI test is the gate.

## Upstream C is a versioned dependency, not a vendored copy

`build.zig.zon` pins `opal_c` to the opal release tarball (`v3.0.0`). `build.zig`
compiles `src/opal.c` from that package into the `opal` module.

Updating means: new URL and hash, `zig build test`, fix mirrors if the ABI test fails,
then bump this package version to match.

## Package name is `opal`, repository is `opal-zig`

Zig package names should not include `zig`. Consumers depend on `opal` and write
`@import("opal")`. The repository name keeps the `opal-{language}` convention used in
upstream `BINDINGS.md`.

## Version is the bound opal release plus a packaging revision

The version is `<opal version>-<revision>`: `1.0.2-1` is the first release binding
opal `1.0.2`. A binding-only fix bumps the revision (`1.0.2-2`). A new opal release
resets it (`1.0.3-1`). This is the allyourcodebase convention, and it mirrors the
Linux packaging scheme.

Semver reads the revision as a pre-release tag, so `1.0.2-1` sorts before a bare
`1.0.2`. Every release therefore carries the revision from the start, which keeps
ordering monotonic (`1.0.2-1 < 1.0.2-2 < 1.0.3-1`).

Each release gets its own immutable git tag (`v1.0.2-1`). A binding fix is a new
tag, never a moved one, which would break consumers' stored hashes.

The compile-time `OPAL_VERSION_*` macros from `opal.h` are exposed as
`version_major`, `version_minor`, `version_patch`, and packed `version`. They are
hardcoded like the other public constants, and the ABI test checks them against
the C header.

## Instances are plain values

Since opal 2.0.0 the `Opal` struct holds no pointers: every cross reference is an
index into `Opal.op` or `Opal.chan`. An instance can be copied, assigned, memcpy'd,
or relocated freely, and a copy is a complete save state. The binding therefore has
no pinning or no-copy rule, and `init` returns the instance by value in the usual
Zig shape:

```zig
var chip = opal.Opal.init(44100);
```

`create` and `destroy` remain as heap helpers because the instance is about 66 KiB,
which is worth keeping off the stack in deeply nested or threaded code.

## Cross references are index fields with sentinel constants

`op_slot`, `mod_source`, `pair_index`, and `out_source` mirror the
upstream `uint8_t` index fields directly. `pair_index` is the physical 4-op partner,
pre-wired on capable channels even while `chan_type` is two-op. `ch_none` marks only
channels that cannot pair. Whether 4-op is active is `chan_type`. The sentinels are
plain constants (`op_none`, `mod_own_fb`, `ch_none`) rather than a wrapper type: the
fields hold ordinary array indices in the common case, and a typed wrapper would tax
every `chip.op[...]` lookup for the rare sentinel check.

## State fields with named values are non-exhaustive enums

`envelope_stage` and `chan_type` are `int` fields upstream with `#define`d value
sets. The binding types them as `EnvelopeStage` and `ChannelType`, both
`enum(c_int)` with a `_` tag: ABI-identical to the C int, switchable by name, and
a value added by a future opal release stays representable instead of being
undefined behavior. `EnvelopeStage.off` is defined because the header defines it.
The core never writes it. Idle operators sit in `release` with `eg_out` at 511 or
more.

## Flag fields are bytes

Upstream stores mode bits and operator flags as `uint8_t`. The mirrors use `u8`.
A Zig `bool` would make any byte other than 0 or 1 illegal to read back from a
chip that C had filled in.

## Methods are thin camelCase wrappers over the C API

| Decision | Detail |
| :------- | :----- |
| Naming   | `writeReg`, `writeRegBuffered`, `readStatus`, and so on map one to one to the `opal*` functions. |
| `init`   | Returns the instance by value, the conventional Zig constructor shape. |
| `create` / `destroy` | Heap helpers that keep the ~66 KiB instance off the stack. |
| `render` | Fills an interleaved stereo `[]i16` via `opalSample`. Not in C, convenience only. |
| Raw externs | The `opal*` functions remain `pub` for callers that want the C surface directly. |

## Examples live in `examples/<name>/src/`

Each example is a directory with its code under `src/` and room for assets and a
README at the example root, matching upstream opal (`examples/player/src/`,
`examples/web/src/`). The root file is `main.zig`, as in `zig init`. New examples
follow the same shape, and `build.zig` grows a per-example loop with `run-<name>`
steps once there is more than one.

## Slot helpers match the upstream header table

`modulatorSlot(ch)` and `carrierSlot(ch)` use the same channel-to-slot map as
`include/opal/opal.h`, saving callers from restating the table when locating
operator state.
