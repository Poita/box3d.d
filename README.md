# box3d.d

Cross-platform [D](https://dlang.org) bindings for [Box3D](https://github.com/erincatto/box3d)
— Erin Catto's 3D physics engine for games.

Box3D is written in C with a clean C API, which makes these bindings a thin,
`@nogc nothrow` translation of that API. The C source is vendored and built from
source, so the package is self-contained: no system Box3D install required.

- **box3d.d version:** 0.1.0
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
    "box3d": "~>0.1"
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
