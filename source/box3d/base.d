// SPDX-License-Identifier: MIT
/++
    Base functionality: allocator/assert/log overrides, versioning and timing.

    Translated from `box3d/base.h`.
+/
module box3d.base;

@nogc nothrow:

extern (C):

/// Prototype for user allocation function.
/// Params:
///   size = the allocation size in bytes
///   alignment = the required alignment, guaranteed to be a power of 2
alias b3AllocFcn = void* function(int size, int alignment);

/// Prototype for user free function.
/// Params:
///   mem = the memory previously allocated through a `b3AllocFcn`
alias b3FreeFcn = void function(void* mem);

/// Prototype for the user assert callback. Return 0 to skip the debugger break.
alias b3AssertFcn = int function(const(char)* condition, const(char)* fileName, int lineNumber);

/// Prototype for user log callback. Used to log warnings.
alias b3LogFcn = void function(const(char)* message);

/// Override the default allocation functions. Set these during application startup.
void b3SetAllocator(b3AllocFcn allocFcn, b3FreeFcn freeFcn);

/// Returns: the total bytes allocated by Box3D.
int b3GetByteCount();

/// Override the default assert function with a non-null assert callback.
void b3SetAssertFcn(b3AssertFcn assertFcn);

/// Override the default log function with a non-null log callback.
void b3SetLogFcn(b3LogFcn logFcn);

/// Version numbering scheme. See https://semver.org/
struct b3Version
{
    int major; /// Significant changes
    int minor; /// Incremental changes
    int revision; /// Bug fixes
}

/// Returns: the current version of Box3D.
b3Version b3GetVersion();

/// Returns: true if the library was built with BOX3D_DOUBLE_PRECISION (large world mode).
bool b3IsDoublePrecision();

/// Get the absolute number of system ticks. The value is platform specific.
ulong b3GetTicks();

/// Get the milliseconds passed from an initial tick value.
float b3GetMilliseconds(ulong ticks);

/// Get the milliseconds passed from an initial tick value.
/// Resets the passed in value to the current tick value.
float b3GetMillisecondsAndReset(ulong* ticks);

/// Yield to be used in a busy loop.
void b3Yield();

/// Sleep the current thread for a number of milliseconds.
void b3Sleep(int milliseconds);

/// Simple djb2 hash function for determinism testing.
uint b3Hash(uint hash, const(ubyte)* data, int count);

/// Write a binary dump file.
void b3WriteBinaryFile(void* data, int size, const(char)* fileName);

/// Read a binary dump file. The returned memory is allocated with the Box3D allocator.
void* b3ReadBinaryFile(const(char)* prefix, const(char)* fileName, int* memSize);

extern (D):

/// Seed value for `b3Hash`.
enum uint B3_HASH_INIT = 5381;

/// Used to indicate an unset or invalid index value.
enum int B3_NULL_INDEX = -1;
