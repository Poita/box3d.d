// SPDX-FileCopyrightText: 2026 Peter Alexander
// SPDX-License-Identifier: MIT

// In-place world snapshots: save the complete simulation state of a world and
// later restore it, into the same world or another one, so stepping resumes
// bit-identically to the original run. Built on the serializer Box3D's
// recording player uses for its own seek keyframes.

#pragma once

#include "box3d/base.h"
#include "box3d/id.h"

#include <stdbool.h>
#include <stdint.h>

/// Shared geometry registry for a family of snapshots. Images reference hull,
/// mesh, height field and compound geometry by id into this store instead of
/// carrying it, so a snapshot of a world over a large height field stays small.
/// Thread safe: any number of threads may save and restore through one store.
/// A restored world's mesh and height field shapes point into the store, so it
/// must outlive every world restored from it.
typedef struct b3SnapshotStore b3SnapshotStore;

/// Create an empty snapshot store.
B3_API b3SnapshotStore* b3CreateSnapshotStore( void );

/// Destroy a store. Destroy every world restored from it first.
B3_API void b3DestroySnapshotStore( b3SnapshotStore* store );

/// Serialize the complete state of an unlocked world: bodies, shapes, contacts
/// with their warm-start impulses, islands, sleep timers, the broad-phase trees
/// and the id pools. Body, shape and joint user data ride along as raw pointer
/// values. Writes a b3Alloc'd image to *outData and returns its size in bytes;
/// release it with b3FreeSnapshot.
B3_API int b3World_SaveSnapshot( b3WorldId worldId, b3SnapshotStore* store, uint8_t** outData );

/// Release an image returned by b3World_SaveSnapshot.
B3_API void b3FreeSnapshot( uint8_t* data, int size );

/// Replace the whole simulation state of an unlocked world with an image saved
/// through the same store. The world keeps its id, so body/shape/joint ids from
/// the saving world are valid here once their world field names this world.
/// Stepping afterwards reproduces the saving world's steps exactly.
/// Returns false on a corrupt or incompatible image; the world is then in an
/// unspecified state and should be destroyed.
B3_API bool b3World_RestoreSnapshot( b3WorldId worldId, b3SnapshotStore* store, const uint8_t* data, int size );
