// SPDX-License-Identifier: MIT
/++
    Tuning constants and length-unit configuration.

    Translated from `box3d/constants.h`. Values that the C header derives from
    `b3GetLengthUnitsPerMeter()` are exposed here as functions, since they depend
    on runtime configuration; the remaining fixed values are manifest constants.
+/
module box3d.constants;

import box3d.math_functions : B3_PI;

@nogc nothrow:

extern (C):

/// Box3D bases all length units on meters, but you may need different units for
/// your game. Set this value at application startup, before any calls to Box3D,
/// and only modify it once. Default value is 1.
void b3SetLengthUnitsPerMeter(float lengthUnits);

/// Get the current length units per meter.
float b3GetLengthUnitsPerMeter();

/// Set the threshold for logging stalls, in seconds.
void b3SetStallThreshold(float seconds);

/// Get the threshold for logging stalls, in seconds.
float b3GetStallThreshold();

extern (D):

/// Maximum parallel workers. Used for some fixed size arrays.
enum int B3_MAX_WORKERS = 32;

/// Maximum number of tasks queued per world step.
enum int B3_MAX_TASKS = 256;

/// Maximum number of colors in the constraint graph.
enum int B3_GRAPH_COLOR_COUNT = 24;

/// Number of contact point buckets used when counting contact points per shape
/// contact pair. Only affects reporting, not simulation.
enum int B3_CONTACT_MANIFOLD_COUNT_BUCKETS = 8;

/// Maximum number of simultaneous worlds that can be allocated.
enum int B3_MAX_WORLDS = 128;

/// The maximum rotation of a body per time step.
enum float B3_MAX_ROTATION = 0.25f * B3_PI;

/// The default contact recycling world angle threshold. For performance this
/// value is cos(angle/2)^2 and corresponds to 10 degrees.
enum float B3_CONTACT_RECYCLE_ANGULAR_DISTANCE = 0.99240388f;

/// Per-shape AABB margin is a fraction of the shape extent (capped by `B3_MAX_AABB_MARGIN`).
enum float B3_AABB_MARGIN_FRACTION = 0.125f;

/// The time that a body must be still before it will go to sleep. In seconds.
enum float B3_TIME_TO_SLEEP = 0.5f;

/// Maximum length of the body name.
enum int B3_BODY_NAME_LENGTH = 18;

/// Maximum length of the shape name.
enum int B3_SHAPE_NAME_LENGTH = 18;

/// The maximum number of contact points between two touching shapes.
enum int B3_MAX_MANIFOLD_POINTS = 4;

/// The maximum number of points to use for shape cast proxies (swept point cloud).
enum int B3_MAX_SHAPE_CAST_POINTS = 64;

/// Shape/child hashing limits. See `b3ShapePairKey`.
enum int B3_SHAPE_POWER = 22;
enum int B3_CHILD_POWER = 64 - 2 * B3_SHAPE_POWER; /// ditto
enum int B3_MAX_SHAPES = 1 << B3_SHAPE_POWER; /// ditto
enum int B3_MAX_CHILD_SHAPES = 1 << B3_CHILD_POWER; /// ditto

/// Used to detect bad values. Depends on the configured length units.
pragma(inline, true) float B3_HUGE() => 1.0e5f * b3GetLengthUnitsPerMeter();

/// A small length used as a collision and constraint tolerance, in meters.
pragma(inline, true) float B3_LINEAR_SLOP() => 0.005f * b3GetLengthUnitsPerMeter();

/// The minimum length of a capsule segment.
pragma(inline, true) float B3_MIN_CAPSULE_LENGTH() => B3_LINEAR_SLOP();

/// The distance between shapes where they are considered overlapped.
pragma(inline, true) float B3_OVERLAP_SLOP() => 0.1f * B3_LINEAR_SLOP();

/// Limited speculative collision distance. Reduces jitter.
pragma(inline, true) float B3_SPECULATIVE_DISTANCE() => 4.0f * B3_LINEAR_SLOP();

/// The rest offset used for mesh contact to reduce ghost collisions and assist with CCD.
pragma(inline, true) float B3_MESH_REST_OFFSET() => 1.0f * B3_LINEAR_SLOP();

/// The default contact recycling distance.
pragma(inline, true) float B3_CONTACT_RECYCLE_DISTANCE() => 10.0f * B3_LINEAR_SLOP();

/// This is used to fatten AABBs in the dynamic tree, in meters.
pragma(inline, true) float B3_MAX_AABB_MARGIN() => 0.05f * b3GetLengthUnitsPerMeter();
