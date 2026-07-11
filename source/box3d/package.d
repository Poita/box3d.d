// SPDX-License-Identifier: MIT
/++
    Cross-platform D bindings for Box3D, the 3D physics engine.

    Import this module to get the whole API:
    ---
    import box3d;
    ---

    See the individual modules for focused imports:
    $(UL
      $(LI $(D box3d.base) — allocator/assert/log overrides, versioning, timing)
      $(LI $(D box3d.id) — opaque handle id types)
      $(LI $(D box3d.constants) — tuning constants, length-unit configuration)
      $(LI $(D box3d.math_functions) — vector math types and functions)
      $(LI $(D box3d.collision) — geometry, hulls, meshes, distance, manifolds, dynamic tree)
      $(LI $(D box3d.types) — world/body/shape/joint definitions, events, debug draw)
      $(LI $(D box3d.functions) — the main world/body/shape/joint API)
    )
+/
module box3d;

public import box3d.base;
public import box3d.id;
public import box3d.constants;
public import box3d.math_functions;
public import box3d.collision;
public import box3d.types;
public import box3d.functions;
