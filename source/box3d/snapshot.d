// SPDX-License-Identifier: MIT
/++
    In-place world snapshots: save the complete simulation state of a world and
    restore it later, into the same world or another one, so stepping resumes
    bit-identically to the original run — the building block for rewind,
    rollback and seekable replays.

    Box3D keeps its world serializer internal (its recording player uses it for
    seek keyframes); these functions are this package's thin public wrapper,
    compiled from `native/box3d_ext/snapshot.c`.
+/
module box3d.snapshot;

import box3d.id : b3WorldId;

/// Shared geometry registry for a family of snapshots. Images reference hull,
/// mesh, height field and compound geometry by id into the store instead of
/// carrying it. Thread safe. A restored world's mesh and height field shapes
/// point into the store, so it must outlive every world restored from it.
struct b3SnapshotStore;

extern (C) nothrow @nogc
{

    /// Create an empty snapshot store.
    b3SnapshotStore* b3CreateSnapshotStore();

    /// Destroy a store. Destroy every world restored from it first.
    void b3DestroySnapshotStore(b3SnapshotStore* store);

    /// Serialize the complete state of an unlocked world (bodies, shapes, contacts
    /// with warm-start impulses, islands, sleep timers, broad-phase trees, id
    /// pools). Body, shape and joint user data ride along as raw pointer values.
    /// Writes the image to `*outData` and returns its size; release it with
    /// `b3FreeSnapshot`.
    int b3World_SaveSnapshot(b3WorldId worldId, b3SnapshotStore* store, ubyte** outData);

    /// Release an image returned by `b3World_SaveSnapshot`.
    void b3FreeSnapshot(ubyte* data, int size);

    /// Replace the whole simulation state of an unlocked world with an image saved
    /// through the same store. The world keeps its id: ids from the saving world
    /// are valid here once their `world0` names this world. Returns false on a
    /// corrupt or incompatible image.
    bool b3World_RestoreSnapshot(b3WorldId worldId, b3SnapshotStore* store, const(ubyte)* data, int size);
}

version (unittest)
{
    import box3d.collision;
    import box3d.functions;
    import box3d.math_functions;
    import box3d.types;
    import box3d.id;

    // A wave height field under a pile of falling cubes: exercises registry
    // geometry (the field, the shared cube hull), contacts, islands and sleep.
    private struct Scene
    {
        b3WorldId world;
        b3BodyId[] boxes;
        b3HeightFieldData* field;
    }

    private Scene makeScene()
    {
        Scene s;
        b3WorldDef wd = b3DefaultWorldDef();
        wd.gravity = b3Vec3(0, -10, 0);
        s.world = b3CreateWorld(&wd);

        s.field = b3CreateWave(16, 16, b3Vec3(1, 1, 1), 0.4f, 0.3f, false);
        b3BodyDef gd = b3DefaultBodyDef();
        gd.position = b3Vec3(-8, 0, -8);
        const ground = b3CreateBody(s.world, &gd);
        b3ShapeDef gs = b3DefaultShapeDef();
        b3CreateHeightFieldShape(ground, &gs, s.field);

        b3BoxHull cube = b3MakeCubeHull(0.4f);
        foreach (i; 0 .. 24)
        {
            b3BodyDef bd = b3DefaultBodyDef();
            bd.type = b3BodyType.b3_dynamicBody;
            bd.position = b3Vec3((i % 4) * 0.9f - 1.5f, 3 + (i / 4) * 0.95f, (i % 3) * 0.3f);
            const b = b3CreateBody(s.world, &bd);
            b3ShapeDef sd = b3DefaultShapeDef();
            sd.density = 1;
            b3CreateHullShape(b, &sd, &cube.base);
            b3Body_SetUserData(b, cast(void*)(0x1000 + i));
            s.boxes ~= b;
        }
        return s;
    }

    private void destroyScene(ref Scene s)
    {
        b3DestroyWorld(s.world);
        b3DestroyHeightField(s.field);
    }

    // Bit pattern of every box's pose and velocity after each of `steps` steps.
    private uint[] trace(b3WorldId world, const(b3BodyId)[] boxes, int steps)
    {
        uint[] bits;
        foreach (_; 0 .. steps)
        {
            b3World_Step(world, 1.0f / 60.0f, 4);
            foreach (b; boxes)
            {
                const x = b3Body_GetTransform(b);
                const v = b3Body_GetLinearVelocity(b);
                foreach (f; [x.p.x, x.p.y, x.p.z, x.q.v.x, x.q.v.y, x.q.v.z, x.q.s, v.x, v.y, v.z])
                    bits ~= *cast(const(uint)*)&f;
            }
        }
        return bits;
    }

    // `boxes` re-pointed at `world` (same index and generation).
    private b3BodyId[] rebind(const(b3BodyId)[] boxes, b3WorldId world)
    {
        b3BodyId[] r;
        foreach (b; boxes)
            r ~= b3BodyId(b.index1, cast(ushort)(world.index1 - 1), b.generation);
        return r;
    }
}

/// Restoring into the same world after it moved on replays the same steps.
unittest
{
    auto s = makeScene();
    scope (exit)
        destroyScene(s);
    auto store = b3CreateSnapshotStore();
    scope (exit)
        b3DestroySnapshotStore(store);

    trace(s.world, s.boxes, 45); // Mid-fall: contacts, warm starts, awake islands.
    ubyte* img;
    const size = b3World_SaveSnapshot(s.world, store, &img);
    scope (exit)
        b3FreeSnapshot(img, size);
    const expected = trace(s.world, s.boxes, 120);

    assert(b3World_RestoreSnapshot(s.world, store, img, size));
    assert(trace(s.world, s.boxes, 120) == expected);
}

/// Restoring into a different world reproduces the saving world's steps, and
/// body user data survives.
unittest
{
    auto a = makeScene();
    scope (exit)
        destroyScene(a);
    auto store = b3CreateSnapshotStore();
    scope (exit)
        b3DestroySnapshotStore(store);

    trace(a.world, a.boxes, 45);
    ubyte* img;
    const size = b3World_SaveSnapshot(a.world, store, &img);
    scope (exit)
        b3FreeSnapshot(img, size);
    const expected = trace(a.world, a.boxes, 120);

    // An empty world: everything comes from the image.
    b3WorldDef wd = b3DefaultWorldDef();
    const other = b3CreateWorld(&wd);
    scope (exit)
        b3DestroyWorld(other);
    assert(b3World_RestoreSnapshot(other, store, img, size));
    const boxes = rebind(a.boxes, other);
    foreach (i, b; boxes)
        assert(b3Body_GetUserData(b) == cast(void*)(0x1000 + i));
    assert(trace(other, boxes, 120) == expected);
}

/// A corrupt image is refused rather than half-applied.
unittest
{
    auto s = makeScene();
    scope (exit)
        destroyScene(s);
    auto store = b3CreateSnapshotStore();
    scope (exit)
        b3DestroySnapshotStore(store);
    ubyte* img;
    const size = b3World_SaveSnapshot(s.world, store, &img);
    scope (exit)
        b3FreeSnapshot(img, size);
    assert(!b3World_RestoreSnapshot(s.world, store, img, size - 1));
    img[0] ^= 0xFF;
    assert(!b3World_RestoreSnapshot(s.world, store, img, size));
    img[0] ^= 0xFF;
}
