// SPDX-FileCopyrightText: 2026 Peter Alexander
// SPDX-License-Identifier: MIT

#include "snapshot.h"

#include "box3d/box3d.h"

#include "body.h"
#include "core.h"
#include "joint.h"
#include "physics_world.h"
#include "recording.h"
#include "recording_replay.h"
#include "shape.h"
#include "world_snapshot.h"

#include <string.h>

struct b3SnapshotStore
{
	// Owns the geometry registry that images reference by id.
	b3Recording* rec;

	// Restore-side view of the registry, one slot per entry. Slots borrow the
	// entry bytes; `live` holds a compound decoded on first use.
	b3RegistrySlot* slots;
	int slotCount;
	int slotCapacity;

	b3Mutex* lock;
};

// Image layout: header, the three user-data tables (one pointer per slot of
// the body, shape and joint arrays), then the Box3D world image.
typedef struct b3SnapshotHeader
{
	uint32_t magic;
	int bodyCount;
	int shapeCount;
	int jointCount;
	int imageSize;
	int reserved;
} b3SnapshotHeader;

#define B3_SNAPSHOT_MAGIC 0x50414E53u // "SNAP"

b3SnapshotStore* b3CreateSnapshotStore( void )
{
	b3SnapshotStore* store = (b3SnapshotStore*)b3AllocZeroed( sizeof( b3SnapshotStore ) );
	store->rec = b3CreateRecording( 0 );
	store->lock = b3CreateMutex();
	return store;
}

void b3DestroySnapshotStore( b3SnapshotStore* store )
{
	if ( store == NULL )
	{
		return;
	}
	for ( int i = 0; i < store->slotCount; ++i )
	{
		b3RegistrySlot* slot = store->slots + i;
		if ( slot->live != NULL )
		{
			b3Free( slot->live, (size_t)slot->byteCount );
		}
	}
	if ( store->slots != NULL )
	{
		b3Free( store->slots, (size_t)store->slotCapacity * sizeof( b3RegistrySlot ) );
	}
	b3DestroyRecording( store->rec );
	b3DestroyMutex( store->lock );
	b3Free( store, sizeof( b3SnapshotStore ) );
}

// Extend the slot view to cover registry entries interned since the last
// restore. Caller holds the lock.
static void b3SyncSlots( b3SnapshotStore* store )
{
	const b3GeometryRegistry* reg = &store->rec->registry;
	if ( reg->count > store->slotCapacity )
	{
		int newCap = reg->count < 16 ? 16 : reg->count * 2;
		store->slots = (b3RegistrySlot*)b3GrowAlloc( store->slots, store->slotCapacity * (int)sizeof( b3RegistrySlot ),
													 newCap * (int)sizeof( b3RegistrySlot ) );
		store->slotCapacity = newCap;
	}
	for ( int i = store->slotCount; i < reg->count; ++i )
	{
		const b3GeometryEntry* entry = reg->entries + i;
		b3RegistrySlot* slot = store->slots + i;
		slot->kind = entry->kind;
		slot->byteCount = entry->byteCount;
		slot->bytes = entry->bytes;
		slot->live = NULL;
	}
	store->slotCount = reg->count;
}

int b3World_SaveSnapshot( b3WorldId worldId, b3SnapshotStore* store, uint8_t** outData )
{
	b3World* world = b3GetWorldFromId( worldId );
	B3_ASSERT( world != NULL && world->locked == false );

	b3RecBuffer image = { 0 };
	b3LockMutex( store->lock );
	b3SerializeWorld( world, &image, store->rec );
	b3UnlockMutex( store->lock );

	b3SnapshotHeader hdr = { 0 };
	hdr.magic = B3_SNAPSHOT_MAGIC;
	hdr.bodyCount = world->bodies.count;
	hdr.shapeCount = world->shapes.count;
	hdr.jointCount = world->joints.count;
	hdr.imageSize = image.size;

	size_t tables = ( (size_t)hdr.bodyCount + (size_t)hdr.shapeCount + (size_t)hdr.jointCount ) * sizeof( void* );
	size_t total = sizeof( hdr ) + tables + (size_t)image.size;
	uint8_t* out = (uint8_t*)b3Alloc( total );
	uint8_t* p = out;
	memcpy( p, &hdr, sizeof( hdr ) );
	p += sizeof( hdr );
	for ( int i = 0; i < hdr.bodyCount; ++i, p += sizeof( void* ) )
	{
		memcpy( p, &world->bodies.data[i].userData, sizeof( void* ) );
	}
	for ( int i = 0; i < hdr.shapeCount; ++i, p += sizeof( void* ) )
	{
		memcpy( p, &world->shapes.data[i].userData, sizeof( void* ) );
	}
	for ( int i = 0; i < hdr.jointCount; ++i, p += sizeof( void* ) )
	{
		memcpy( p, &world->joints.data[i].userData, sizeof( void* ) );
	}
	memcpy( p, image.data, (size_t)image.size );

	if ( image.data != NULL )
	{
		b3Free( image.data, (size_t)image.capacity );
	}
	*outData = out;
	return (int)total;
}

void b3FreeSnapshot( uint8_t* data, int size )
{
	if ( data != NULL )
	{
		b3Free( data, (size_t)size );
	}
}

bool b3World_RestoreSnapshot( b3WorldId worldId, b3SnapshotStore* store, const uint8_t* data, int size )
{
	b3World* world = b3GetWorldFromId( worldId );
	B3_ASSERT( world != NULL && world->locked == false );

	b3SnapshotHeader hdr;
	if ( data == NULL || size < (int)sizeof( hdr ) )
	{
		return false;
	}
	memcpy( &hdr, data, sizeof( hdr ) );
	size_t tables = ( (size_t)hdr.bodyCount + (size_t)hdr.shapeCount + (size_t)hdr.jointCount ) * sizeof( void* );
	if ( hdr.magic != B3_SNAPSHOT_MAGIC || hdr.bodyCount < 0 || hdr.shapeCount < 0 || hdr.jointCount < 0 ||
		 hdr.imageSize < 0 || sizeof( hdr ) + tables + (size_t)hdr.imageSize != (size_t)size )
	{
		return false;
	}
	const uint8_t* userTables = data + sizeof( hdr );
	const uint8_t* image = userTables + tables;

	b3RecReader rdr;
	memset( &rdr, 0, sizeof( rdr ) );
	rdr.data = image;
	rdr.size = hdr.imageSize;
	rdr.replayWorldId = worldId;
	rdr.ok = true;

	b3LockMutex( store->lock );
	b3SyncSlots( store );
	rdr.slots = store->slots;
	rdr.slotCount = store->slotCount;
	bool ok = b3DeserializeIntoShell( image, hdr.imageSize, world, &rdr );
	b3UnlockMutex( store->lock );

	if ( ok == false || world->bodies.count != hdr.bodyCount || world->shapes.count != hdr.shapeCount ||
		 world->joints.count != hdr.jointCount )
	{
		return false;
	}

	const uint8_t* p = userTables;
	for ( int i = 0; i < hdr.bodyCount; ++i, p += sizeof( void* ) )
	{
		memcpy( &world->bodies.data[i].userData, p, sizeof( void* ) );
	}
	for ( int i = 0; i < hdr.shapeCount; ++i, p += sizeof( void* ) )
	{
		memcpy( &world->shapes.data[i].userData, p, sizeof( void* ) );
	}
	for ( int i = 0; i < hdr.jointCount; ++i, p += sizeof( void* ) )
	{
		memcpy( &world->joints.data[i].userData, p, sizeof( void* ) );
	}
	return true;
}
