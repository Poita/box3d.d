# box3d.d

Cross-platform [D](https://dlang.org) bindings for [Box3D](https://github.com/erincatto/box3d)
— Erin Catto's 3D physics engine for games.

Box3D is written in C with a clean C API, which makes these bindings a thin,
`@nogc nothrow` translation of that API. The C source is vendored and built from
source, so the package is self-contained: no system Box3D install required.

- **box3d.d version:** 1.0.0
- **Box3D version:** 0.1.0 (vendored under `native/box3d`)
- **License:** MIT (both these bindings and Box3D itself)
- **Precision:** single precision (the default Box3D build)

## Installation

Add the dependency with dub:

```sh
dub add box3d
```

or in your `dub.json`:

```json
"dependencies": {
    "box3d": "~>1.0"
}
```

### Build requirements

The default `vendored` configuration compiles the bundled Box3D C source into a
static library the first time you build, and links it automatically. This needs:

- **CMake** (3.16+) on `PATH`
- A **C17 compiler** (clang, gcc, or MSVC)

These are only needed at build time. If you would rather link a Box3D library
that is already installed on your system, use the `system` configuration:

```json
"subConfigurations": {
    "box3d": "system"
}
```

## Usage

```d
import box3d;

void main()
{
    b3WorldDef worldDef = b3DefaultWorldDef();
    worldDef.gravity = b3Vec3(0.0f, -10.0f, 0.0f);
    b3WorldId world = b3CreateWorld(&worldDef);
    scope (exit) b3DestroyWorld(world);

    // Static ground.
    b3BodyDef groundDef = b3DefaultBodyDef();
    groundDef.position = b3Vec3(0.0f, -10.0f, 0.0f);
    b3BodyId ground = b3CreateBody(world, &groundDef);
    b3BoxHull groundBox = b3MakeBoxHull(50.0f, 10.0f, 50.0f);
    b3ShapeDef groundShape = b3DefaultShapeDef();
    b3CreateHullShape(ground, &groundShape, &groundBox.base);

    // A falling box.
    b3BodyDef bodyDef = b3DefaultBodyDef();
    bodyDef.type = b3BodyType.b3_dynamicBody;
    bodyDef.position = b3Vec3(0.0f, 8.0f, 0.0f);
    b3BodyId box = b3CreateBody(world, &bodyDef);
    b3BoxHull dynamicBox = b3MakeCubeHull(0.5f);
    b3ShapeDef shapeDef = b3DefaultShapeDef();
    shapeDef.density = 1.0f;
    b3CreateHullShape(box, &shapeDef, &dynamicBox.base);

    foreach (_; 0 .. 90)
    {
        b3World_Step(world, 1.0f / 60.0f, 4);
        b3Vec3 p = b3Body_GetPosition(box);
        // use p ...
    }
}
```

Run the bundled example:

```sh
dub run box3d:hello
```

## API layout

Import `box3d` to get everything, or import a focused module:

| Module                 | Contents |
|------------------------|----------|
| `box3d.base`           | allocator / assert / log overrides, versioning, timing |
| `box3d.id`             | opaque handle id types (`b3WorldId`, `b3BodyId`, …) |
| `box3d.constants`      | tuning constants, length-unit configuration |
| `box3d.math_functions` | vector math types and functions (`b3Vec3`, `b3Quat`, …) |
| `box3d.collision`      | geometry, hulls, meshes, distance, manifolds, the dynamic tree |
| `box3d.types`          | world/body/shape/joint definitions, events, debug draw |
| `box3d.functions`      | the main world/body/shape/joint API |

Box3D's `config.h` contains only compile-time build options (precision, SIMD)
and defines no symbols, so it has no D module; the bindings target the default
configuration.

### D conveniences

The bindings mirror the C API name-for-name (`b3CreateWorld`, `b3World_Step`,
…), so the official Box3D documentation applies directly. On top of that:

- The header-only inline math helpers (`b3Add`, `b3Dot`, `b3MulRot`, …) are
  reimplemented in pure D, so they inline without calling into the C library.
- `b3Vec3` gains idiomatic operator overloads (`a + b`, `a - b`, `s * v`,
  `v * s`, `-v`, `+=`, `-=`, `*=`) in addition to the free functions.
- Enum members are scoped (e.g. `b3BodyType.b3_dynamicBody`).

## Precision

These bindings target the default single-precision Box3D build, so `b3Pos`
aliases `b3Vec3` and `b3WorldTransform` aliases `b3Transform`. Box3D emits a link
error if an application and library disagree on precision, so a mismatch cannot
go unnoticed.

## Determinism

Box3D simulates bit-identically across operating systems and CPU architectures,
and the `determinism` workflow verifies it on every push over Linux x64, Windows
x64 and macOS arm64 — three operating systems and both architectures.

Box3D itself does most of the work. The solver calls no transcendental
functions: `sinf`, `cosf` and `atan2f` are replaced by in-tree polynomial
approximations, approximate reciprocals are banned from the SIMD paths, and the
SIMD width is pinned to 4 on SSE2, NEON and the scalar fallback alike. What
remains is `+ - * /` and `sqrt`, which IEEE 754 specifies to the bit. Ordering
is deterministic too: contact creation, broadphase pairs, island tie-breaks and
sensor events all have a defined order independent of worker scheduling.

That leaves the build, which this package pins in `native/box3d/CMakeLists.txt`:

- **`-ffp-contract=off`** (`/fp:precise` on MSVC). Without it, `a + s * b` —
  `b3MulAdd`, the solver's hottest expression — fuses into a single `fmadd` on
  arm64 and rounds once where x86-64 rounds twice. This is not a subtle effect:
  building with contraction enabled changes the state hash from **frame 0**.
- **No fast math**, which would permit reassociation.
- **SSE2 on 32-bit x86**, so intermediates are not held at x87's 80-bit width.

Two constraints are yours to hold, because they are process state that no
library can own:

- **Do not build your application with `-ffast-math` or `/fp:fast`.** On Linux,
  GCC's `-ffast-math` links `crtfastmath.o`, which enables flush-to-zero for the
  entire process — including Box3D's threads. Denormal handling must match on
  every platform, so if you set FTZ/DAZ (x86) or `FPCR.FZ` (arm64), set it
  everywhere or nowhere.
- **Do not pass `-march=native` or `-mfma`** when building the vendored library.
  Enabling FMA on x86-64 lets the compiler contract there too, diverging from
  other x86-64 builds.

### Checking it yourself

```sh
# Write a per-frame hash of every body's transform and velocity.
dub run box3d:determinism -- --out hashes.txt

# Record a run, then replay it and check against the embedded state hashes.
dub run box3d:determinism -- --record scene.b3rec
dub run box3d:determinism -- --replay scene.b3rec
```

Hash files from two machines should be byte-identical; the first differing line
is the frame where they parted. A recording carries the hashes computed by the
machine that produced it, so copying one to another machine and replaying it
checks against Box3D's own internal hash rather than the harness's.

Note that this gates the D bindings and the C library together, since the inline
math in `source/box3d/math_functions.d` is compiled by your D compiler rather
than the C one. LDC does not contract floating-point expressions by default, so
it agrees with the pinned C flags; if you use GDC, verify before relying on it.

Multithreaded determinism is not yet covered. Box3D is written for it and
`b3RecPlayer_SetWorkerCount` exists to test it, but `b3ValidateReplay` documents
its `workerCount` parameter as reserved in this version, so the harness records
and replays with a single worker.

## Updating the vendored Box3D

The Box3D C source lives in `native/box3d` (`include/` + `src/` + a minimal
`CMakeLists.txt`). The upstream commit is recorded in
`native/box3d/COMMIT.txt`. To update, replace `include/` and `src/` from a newer
Box3D checkout and re-generate any changed bindings.

## Development

Format and lint with the standard D tools:

```sh
dub run dfmt -- --inplace source/box3d/*.d examples/*.d
dub run dscanner -- --styleCheck --config dscanner.ini source/box3d/
```

Style is pinned by `.editorconfig` (dfmt: 4-space indent, Allman braces) and
`dscanner.ini`. The naming, undocumented-declaration and long-line checks are
relaxed because the bindings deliberately mirror the C API names verbatim.

## License

MIT. See [LICENSE](LICENSE). Box3D is © Erin Catto and also MIT licensed; its
license is preserved at `native/box3d/LICENSE`.
