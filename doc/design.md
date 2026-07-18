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

`build.zig.zon` pins `opal_c` to the opal release tarball (`v1.0.2`). `build.zig`
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

## Cross pointers are optional (`?*`)

`Opal_Init` wires `master`, `chan`, `mod`, `channel_pair`, and `out_ptr` into the
instance. Uninitialized storage would make non-optional pointer loads undefined
behavior. Optionals match the C pointer types and stay zero-cost in an `extern struct`.

## Methods are thin camelCase wrappers over the C API

| Decision | Detail |
| :------- | :----- |
| Naming   | `port`, `portBuffered`, `setSampleRate`, and so on map one to one to `Opal_*`. |
| `create` / `destroy` | Heap-pin the ~70 KiB instance so the no-copy rule is the default path. |
| `render` | Fills an interleaved stereo `[]i16` via `Opal_Sample`. Not in C, convenience only. |
| Raw externs | `Opal_*` remain `pub` for callers that want the C surface directly. |

## Instance must not be copied after `init`

`Opal_Init` stores pointers into the instance's own address. Copying or relocating
after init leaves dangling internal pointers. After any move, call `init` again (which
also resets chip state). Prefer `Opal.create`.

## Examples live in `examples/<name>/src/`

Each example is a directory with its code under `src/` and room for assets and a
README at the example root, matching upstream opal (`examples/player/src/`,
`examples/web/src/`). The root file is `main.zig`, as in `zig init`. New examples
follow the same shape, and `build.zig` grows a per-example loop with `run-<name>`
steps once there is more than one.

## Slot helpers match the upstream header table

`modulatorSlot(ch)` and `carrierSlot(ch)` use the same channel-to-slot map as
`include/opal/opal.h`. Prefer these indices when reading operator state from another
thread: the cross pointers still point into the live instance.
