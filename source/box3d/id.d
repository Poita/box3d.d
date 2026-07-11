// SPDX-License-Identifier: MIT
/++
    Opaque handle id types for Box3D objects.

    These ids are handles to internal Box3D objects and should be treated as
    opaque values passed by value. All ids are considered null when zero
    initialized (D default initialization yields a null id).

    Translated from `box3d/id.h`.
+/
module box3d.id;

@safe nothrow @nogc:

/// World id references a world instance. Treat as an opaque handle.
struct b3WorldId
{
    ushort index1;
    ushort generation;
}

/// Body id references a body instance. Treat as an opaque handle.
struct b3BodyId
{
    int index1;
    ushort world0;
    ushort generation;
}

/// Shape id references a shape instance. Treat as an opaque handle.
struct b3ShapeId
{
    int index1;
    ushort world0;
    ushort generation;
}

/// Joint id references a joint instance. Treat as an opaque handle.
struct b3JointId
{
    int index1;
    ushort world0;
    ushort generation;
}

/// Contact id references a contact instance. Treat as an opaque handle.
struct b3ContactId
{
    int index1;
    ushort world0;
    short padding;
    uint generation;
}

/// Null ids. Zero initialization also yields a null id.
enum b3WorldId b3_nullWorldId = b3WorldId.init;
enum b3BodyId b3_nullBodyId = b3BodyId.init; /// ditto
enum b3ShapeId b3_nullShapeId = b3ShapeId.init; /// ditto
enum b3JointId b3_nullJointId = b3JointId.init; /// ditto
enum b3ContactId b3_nullContactId = b3ContactId.init; /// ditto

/// True if the id is null (any id type).
pragma(inline, true) bool B3_IS_NULL(Id)(Id id) pure
{
    return id.index1 == 0;
}

/// True if the id is non-null (any id type).
pragma(inline, true) bool B3_IS_NON_NULL(Id)(Id id) pure
{
    return id.index1 != 0;
}

/// Compare two ids for equality. Does not work for `b3WorldId`. Do not mix types.
pragma(inline, true) bool B3_ID_EQUALS(Id)(Id id1, Id id2) pure
{
    return id1.index1 == id2.index1 && id1.world0 == id2.world0 && id1.generation == id2.generation;
}

/// Store a world id into a `uint`.
pragma(inline, true) uint b3StoreWorldId(b3WorldId id) pure
{
    return (cast(uint) id.index1 << 16) | cast(uint) id.generation;
}

/// Load a `uint` into a world id.
pragma(inline, true) b3WorldId b3LoadWorldId(uint x) pure
{
    return b3WorldId(cast(ushort)(x >> 16), cast(ushort) x);
}

/// Store a body id into a `ulong`.
pragma(inline, true) ulong b3StoreBodyId(b3BodyId id) pure
{
    return (cast(ulong) id.index1 << 32) | (cast(ulong) id.world0) << 16 | cast(ulong) id.generation;
}

/// Load a `ulong` into a body id.
pragma(inline, true) b3BodyId b3LoadBodyId(ulong x) pure
{
    return b3BodyId(cast(int)(x >> 32), cast(ushort)(x >> 16), cast(ushort) x);
}

/// Store a shape id into a `ulong`.
pragma(inline, true) ulong b3StoreShapeId(b3ShapeId id) pure
{
    return (cast(ulong) id.index1 << 32) | (cast(ulong) id.world0) << 16 | cast(ulong) id.generation;
}

/// Load a `ulong` into a shape id.
pragma(inline, true) b3ShapeId b3LoadShapeId(ulong x) pure
{
    return b3ShapeId(cast(int)(x >> 32), cast(ushort)(x >> 16), cast(ushort) x);
}

/// Store a joint id into a `ulong`.
pragma(inline, true) ulong b3StoreJointId(b3JointId id) pure
{
    return (cast(ulong) id.index1 << 32) | (cast(ulong) id.world0) << 16 | cast(ulong) id.generation;
}

/// Load a `ulong` into a joint id.
pragma(inline, true) b3JointId b3LoadJointId(ulong x) pure
{
    return b3JointId(cast(int)(x >> 32), cast(ushort)(x >> 16), cast(ushort) x);
}

/// Store a contact id into three `uint` values.
pragma(inline, true) void b3StoreContactId(b3ContactId id, ref uint[3] values) pure
{
    values[0] = cast(uint) id.index1;
    values[1] = cast(uint) id.world0;
    values[2] = cast(uint) id.generation;
}

/// Load three `uint` values into a contact id.
pragma(inline, true) b3ContactId b3LoadContactId(ref const uint[3] values) pure
{
    b3ContactId id;
    id.index1 = cast(int) values[0];
    id.world0 = cast(ushort) values[1];
    id.padding = 0;
    id.generation = cast(uint) values[2];
    return id;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@safe unittest
{
    // Body id survives a store/load round trip.
    b3BodyId id = b3BodyId(0x01234567, 0xABCD, 0x89EF);
    assert(b3LoadBodyId(b3StoreBodyId(id)) == id);
}

@safe unittest
{
    // World id survives a store/load round trip.
    b3WorldId id = b3WorldId(0x1234, 0x5678);
    assert(b3LoadWorldId(b3StoreWorldId(id)) == id);
}

@safe unittest
{
    // A zero-initialized id is null; a non-zero index is non-null.
    assert(B3_IS_NULL(b3BodyId.init));
    assert(B3_IS_NON_NULL(b3BodyId(1, 0, 0)));
}

@safe unittest
{
    // Contact ids round trip through three uint values.
    b3ContactId id = b3ContactId(0x11223344, 0x5566, 0, 0x99AABBCC);
    uint[3] values;
    b3StoreContactId(id, values);
    assert(b3LoadContactId(values) == id);
}
