// SPDX-License-Identifier: MIT
/++
    Public definitions: world/body/shape/joint definitions, events, queries,
    geometry (spheres, capsules, hulls, meshes, height fields, compounds),
    the dynamic tree, contact manifolds, callbacks and debug draw.

    Translated from `box3d/types.h`.
+/
module box3d.types;

import box3d.constants;
import box3d.id;
import box3d.math_functions;

/// Default collision category bits (all bits set).
enum ulong B3_DEFAULT_CATEGORY_BITS = ulong.max;

/// Default collision mask bits (collide with everything).
enum ulong B3_DEFAULT_MASK_BITS = ulong.max;

extern (C) nothrow:

// ---------------------------------------------------------------------------
// Task system callbacks
// ---------------------------------------------------------------------------

/// Prototype for a Box3D task. Run on a worker thread, exactly once per enqueue.
alias b3TaskCallback = void function(void* taskContext);

/// Spawn a task. Returns a pointer to the user's task object (may be null).
/// A null return indicates the work was executed serially within the callback.
/// The task name may be used by the scheduler for diagnostics.
alias b3EnqueueTaskCallback = void* function(b3TaskCallback task, void* taskContext, void* userContext, const(char)* taskName);

/// Finish a user task object that wraps a Box3D task. This must block until the
/// task has completed. `b3World_Step` holds its stack across every fork/join, so
/// drive the step from a thread you can dedicate to it, or from a fiber this
/// callback can park. A job that blocks on its own sub-jobs without yielding its
/// thread can deadlock.
alias b3FinishTaskCallback = void function(void* userTask, void* userContext);

// ---------------------------------------------------------------------------
// Debug shape callbacks
// ---------------------------------------------------------------------------

/// Create a user debug draw shape for multi-pass rendering. These user shapes are
/// created and destroyed via callback so they can be bound to shape lifetime and
/// scaling updates.
alias b3CreateDebugShapeCallback = void* function(const(b3DebugShape)* debugShape, void* userContext);

/// Destroy a user debug draw shape. Called when a shape is modified or destroyed.
alias b3DestroyDebugShapeCallback = void function(void* userShape, void* userContext);

// ---------------------------------------------------------------------------
// Simulation callbacks
// ---------------------------------------------------------------------------

/// Optional friction mixing callback. Called from a worker thread; do not modify state.
alias b3FrictionCallback = float function(float frictionA, ulong userMaterialIdA, float frictionB, ulong userMaterialIdB);

/// Optional restitution mixing callback. Called from a worker thread; do not modify state.
alias b3RestitutionCallback = float function(float restitutionA, ulong userMaterialIdA, float restitutionB, ulong userMaterialIdB);

/// Contact filter callback. Return false to disable the collision. Must be thread-safe.
/// Only called if one of the two shapes has custom filtering enabled.
alias b3CustomFilterFcn = bool function(b3ShapeId shapeIdA, b3ShapeId shapeIdB, void* context);

/// Pre-solve callback. Return false to disable the contact this step. Must be thread-safe.
alias b3PreSolveFcn = bool function(b3ShapeId shapeIdA, b3ShapeId shapeIdB, b3Pos point, b3Vec3 normal, void* context);

/// Overlap query callback. Return false to terminate the query.
alias b3OverlapResultFcn = bool function(b3ShapeId shapeId, void* context);

/// Ray cast callback. Return -1 to filter, 0 to terminate, a fraction to clip, 1 to continue.
/// The triangle index is provided for mesh or height field shapes (-1 otherwise) and the
/// child index for compound shapes.
alias b3CastResultFcn = float function(b3ShapeId shapeId, b3Pos point, b3Vec3 normal, float fraction,
        ulong userMaterialId, int triangleIndex, int childIndex, void* context);

// ---------------------------------------------------------------------------
// World
// ---------------------------------------------------------------------------

/// Optional world capacities that can be used to avoid run-time allocations.
struct b3Capacity
{
    int staticShapeCount; /// Number of expected static shapes.
    int dynamicShapeCount; /// Number of expected dynamic and kinematic shapes.
    int staticBodyCount; /// Number of expected static bodies.
    int dynamicBodyCount; /// Number of expected dynamic and kinematic bodies.
    int contactCount; /// Number of expected contacts.
}

/// World definition used to create a simulation world.
/// Must be initialized using `b3DefaultWorldDef`.
struct b3WorldDef
{
    b3Vec3 gravity;
    float restitutionThreshold = 0;
    float hitEventThreshold = 0;
    float contactHertz = 0;
    float contactDampingRatio = 0;
    float contactSpeed = 0;
    float maximumLinearSpeed = 0;
    b3FrictionCallback frictionCallback;
    b3RestitutionCallback restitutionCallback;
    bool enableSleep;
    bool enableContinuous;
    uint workerCount; /// Clamped to [1, B3_MAX_WORKERS]. Values above 1 turn on multithreading.
    b3EnqueueTaskCallback enqueueTask;
    b3FinishTaskCallback finishTask;
    void* userTaskContext;
    void* userData;
    b3CreateDebugShapeCallback createDebugShape; /// Called when a shape is first drawn using b3DebugDraw.
    b3DestroyDebugShapeCallback destroyDebugShape; /// Called when a shape is modified or destroyed.
    void* userDebugShapeContext; /// Passed to the debug shape callbacks.
    b3Capacity capacity;
    int internalValue; /// Used internally to detect a valid definition. DO NOT SET.
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

/// The body simulation type.
enum b3BodyType
{
    b3_staticBody = 0, /// zero mass, zero velocity, may be manually moved
    b3_kinematicBody = 1, /// zero mass, velocity set by user, moved by solver
    b3_dynamicBody = 2, /// positive mass, velocity determined by forces, moved by solver
    b3_bodyTypeCount, /// number of body types
}

/// Motion locks to restrict the body movement.
struct b3MotionLocks
{
    bool linearX; /// Prevent translation along the x-axis
    bool linearY; /// Prevent translation along the y-axis
    bool linearZ; /// Prevent translation along the z-axis
    bool angularX; /// Prevent rotation around the x-axis
    bool angularY; /// Prevent rotation around the y-axis
    bool angularZ; /// Prevent rotation around the z-axis
}

/// A body definition holds all the data needed to construct a rigid body.
/// Must be initialized using `b3DefaultBodyDef`.
struct b3BodyDef
{
    b3BodyType type;
    b3Pos position;
    b3Quat rotation;
    b3Vec3 linearVelocity;
    b3Vec3 angularVelocity;
    float linearDamping = 0;
    float angularDamping = 0;
    float gravityScale = 0;
    float sleepThreshold = 0;
    const(char)* name;
    void* userData;
    b3MotionLocks motionLocks;
    bool enableSleep;
    bool isAwake;
    bool isBullet;
    bool isEnabled;
    bool allowFastRotation;
    bool enableContactRecycling;
    int internalValue; /// Used internally to detect a valid definition. DO NOT SET.
}

// ---------------------------------------------------------------------------
// Shape
// ---------------------------------------------------------------------------

/// Collision filtering for shapes. Affects shape-vs-shape and shape-vs-query collision.
struct b3Filter
{
    ulong categoryBits; /// The collision category bits. Normally you would just set one bit.
    ulong maskBits; /// The categories this shape accepts for collision.
    int groupIndex; /// Never collide (negative) or always collide (positive) with the same group.
}

/// Material properties supported per triangle on meshes and height fields.
struct b3SurfaceMaterial
{
    float friction = 0; /// The Coulomb (dry) friction coefficient, usually in [0,1].
    float restitution = 0; /// The coefficient of restitution (bounce), usually in [0,1].
    float rollingResistance = 0; /// The rolling resistance, usually in [0,1]. Only used for spheres and capsules.
    b3Vec3 tangentVelocity; /// The tangent velocity for conveyor belts, local to the shape.
    ulong userMaterialId; /// User material identifier passed with query results.
    uint customColor; /// Custom debug draw color. Low 24 bits RGB, high byte may carry a b3DebugMaterial preset.
}

/// Shape type.
enum b3ShapeType
{
    b3_capsuleShape, /// A capsule is an extruded sphere
    b3_compoundShape, /// A compound shape composed of up to 64K spheres, capsules, hulls, and meshes
    b3_heightShape, /// A height field useful for terrain
    b3_hullShape, /// A convex hull
    b3_meshShape, /// A triangle soup
    b3_sphereShape, /// A sphere with an offset
    b3_shapeTypeCount, /// The number of shape types
}

/// Used to create a shape. Must be initialized using `b3DefaultShapeDef`.
struct b3ShapeDef
{
    void* userData;
    b3SurfaceMaterial* materials; /// Per-triangle materials for mesh shapes. Ignored for convex and compound shapes.
    int materialCount;
    b3SurfaceMaterial baseMaterial; /// The base surface material. Ignored for compound shapes.
    float density = 0;
    float explosionScale = 0;
    b3Filter filter;
    bool enableCustomFiltering;
    bool isSensor;
    bool enableSensorEvents;
    bool enableContactEvents;
    bool enableHitEvents;
    bool enablePreSolveEvents;
    bool invokeContactCreation;
    bool updateBodyMass;
    int internalValue; /// Used internally to detect a valid definition. DO NOT SET.
}

/// Profiling data. Times are in milliseconds.
struct b3Profile
{
    float step = 0;
    float pairs = 0;
    float collide = 0;
    float solve = 0;
    float solverSetup = 0;
    float constraints = 0;
    float prepareConstraints = 0;
    float integrateVelocities = 0;
    float warmStart = 0;
    float solveImpulses = 0;
    float integratePositions = 0;
    float relaxImpulses = 0;
    float applyRestitution = 0;
    float storeImpulses = 0;
    float splitIslands = 0;
    float transforms = 0;
    float sensorHits = 0;
    float jointEvents = 0;
    float hitEvents = 0;
    float refit = 0;
    float bullets = 0;
    float sleepIslands = 0;
    float sensors = 0;
}

/// Counters that give details of the simulation size.
struct b3Counters
{
    int bodyCount;
    int shapeCount;
    int contactCount;
    int jointCount;
    int islandCount;
    int stackUsed;
    int arenaCapacity;
    int staticTreeHeight;
    int treeHeight;
    int satCallCount;
    int satCacheHitCount;
    int byteCount;
    int taskCount;
    int[24] colorCounts;
    int[B3_CONTACT_MANIFOLD_COUNT_BUCKETS] manifoldCounts;
    int awakeContactCount; /// Number of contacts touched by the collide pass.
    int recycledContactCount; /// Number of contacts recycled in the most recent step.
    int distanceIterations; /// Maximum number of time of impact iterations.
    int pushBackIterations;
    int rootIterations;
}

// ---------------------------------------------------------------------------
// Joints
// ---------------------------------------------------------------------------

/// Joint type enumeration.
enum b3JointType
{
    b3_parallelJoint,
    b3_distanceJoint,
    b3_filterJoint,
    b3_motorJoint,
    b3_prismaticJoint,
    b3_revoluteJoint,
    b3_sphericalJoint,
    b3_weldJoint,
    b3_wheelJoint,
}

/// Base joint definition used by all joint types. The local frames are measured
/// from the body's origin rather than the center of mass.
struct b3JointDef
{
    void* userData;
    b3BodyId bodyIdA;
    b3BodyId bodyIdB;
    b3Transform localFrameA;
    b3Transform localFrameB;
    float forceThreshold = 0;
    float torqueThreshold = 0;
    float constraintHertz = 0;
    float constraintDampingRatio = 0;
    float drawScale = 0;
    bool collideConnected;
    int internalValue; /// Used internally to detect a valid definition. DO NOT SET.
}

/// Distance joint definition. Connects a point on body A with a point on body B by a segment.
struct b3DistanceJointDef
{
    b3JointDef base;
    float length = 0;
    bool enableSpring;
    float lowerSpringForce = 0;
    float upperSpringForce = 0;
    float hertz = 0;
    float dampingRatio = 0;
    bool enableLimit;
    float minLength = 0;
    float maxLength = 0;
    bool enableMotor;
    float maxMotorForce = 0;
    float motorSpeed = 0;
}

/// A motor joint is used to control the relative position and velocity between two bodies.
struct b3MotorJointDef
{
    b3JointDef base;
    b3Vec3 linearVelocity;
    float maxVelocityForce = 0;
    b3Vec3 angularVelocity;
    float maxVelocityTorque = 0;
    float linearHertz = 0;
    float linearDampingRatio = 0;
    float maxSpringForce = 0;
    float angularHertz = 0;
    float angularDampingRatio = 0;
    float maxSpringTorque = 0;
}

/// A filter joint disables collision between two specific bodies.
struct b3FilterJointDef
{
    b3JointDef base;
}

/// Parallel joint definition. Constrains the angle between axis z in body A and axis z
/// in body B using a spring. Useful to keep a body upright.
struct b3ParallelJointDef
{
    b3JointDef base;
    float hertz = 0;
    float dampingRatio = 0;
    float maxTorque = 0;
}

/// Prismatic joint definition. Body B may slide along the x-axis in local frame A.
/// Body B cannot rotate relative to body A.
struct b3PrismaticJointDef
{
    b3JointDef base;
    bool enableSpring;
    float hertz = 0;
    float dampingRatio = 0;
    float targetTranslation = 0;
    bool enableLimit;
    float lowerTranslation = 0;
    float upperTranslation = 0;
    bool enableMotor;
    float maxMotorForce = 0;
    float motorSpeed = 0;
}

/// Revolute joint definition. A point on body B is fixed to a point on body A.
/// Allows relative rotation about the z-axis.
struct b3RevoluteJointDef
{
    b3JointDef base;
    float targetAngle = 0;
    bool enableSpring;
    float hertz = 0;
    float dampingRatio = 0;
    bool enableLimit;
    float lowerAngle = 0;
    float upperAngle = 0;
    bool enableMotor;
    float maxMotorTorque = 0;
    float motorSpeed = 0;
}

/// Spherical joint definition. A point on body B is fixed to a point on body A.
/// Allows rotation about the shared point.
struct b3SphericalJointDef
{
    b3JointDef base;
    bool enableSpring;
    float hertz = 0;
    float dampingRatio = 0;
    b3Quat targetRotation; /// Target spring rotation, joint frame B relative to joint frame A.
    bool enableConeLimit; /// The cone is centered on the frameA z-axis.
    float coneAngle = 0; /// The angle for the cone limit in radians. Valid range is [0, pi].
    bool enableTwistLimit; /// The twist is centered on the frameB z-axis.
    float lowerTwistAngle = 0; /// The lower twist limit in radians. Minimum of -0.99*pi radians.
    float upperTwistAngle = 0; /// The upper twist limit in radians. Maximum of 0.99*pi radians.
    bool enableMotor;
    float maxMotorTorque = 0;
    b3Vec3 motorVelocity; /// The desired motor angular velocity in radians per second.
}

/// Weld joint definition. Connects two bodies together rigidly. This constraint
/// provides springs to mimic soft-body simulation.
struct b3WeldJointDef
{
    b3JointDef base;
    float linearHertz = 0;
    float angularHertz = 0;
    float linearDampingRatio = 0;
    float angularDampingRatio = 0;
}

/// Wheel joint definition. Body A is the chassis and body B is the wheel.
/// The wheel rotates around the local z-axis in frame B and translates along
/// the local x-axis in frame A, with optional steering about the x-axis in frame A.
struct b3WheelJointDef
{
    b3JointDef base;
    bool enableSuspensionSpring;
    float suspensionHertz = 0;
    float suspensionDampingRatio = 0;
    bool enableSuspensionLimit;
    float lowerSuspensionLimit = 0;
    float upperSuspensionLimit = 0;
    bool enableSpinMotor;
    float maxSpinTorque = 0;
    float spinSpeed = 0;
    bool enableSteering;
    float steeringHertz = 0;
    float steeringDampingRatio = 0;
    float targetSteeringAngle = 0;
    float maxSteeringTorque = 0;
    bool enableSteeringLimit;
    float lowerSteeringLimit = 0;
    float upperSteeringLimit = 0;
}

/// The explosion definition configures options for explosions. Explosions
/// consider shape geometry when computing the impulse.
struct b3ExplosionDef
{
    ulong maskBits;
    b3Pos position;
    float radius = 0;
    float falloff = 0;
    float impulsePerArea = 0; /// Impulse per unit area facing the explosion. May be negative for implosions.
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

/// Generated when a shape starts to overlap a sensor shape.
struct b3SensorBeginTouchEvent
{
    b3ShapeId sensorShapeId;
    b3ShapeId visitorShapeId;
}

/// Generated when a shape stops overlapping a sensor shape. Either shape may
/// have been destroyed; confirm with `b3Shape_IsValid` before use.
struct b3SensorEndTouchEvent
{
    b3ShapeId sensorShapeId;
    b3ShapeId visitorShapeId;
}

/// Sensor events buffered in the world, available after the time step.
struct b3SensorEvents
{
    b3SensorBeginTouchEvent* beginEvents;
    b3SensorEndTouchEvent* endEvents;
    int beginCount;
    int endCount;
}

/// Generated when two shapes begin touching.
struct b3ContactBeginTouchEvent
{
    b3ShapeId shapeIdA;
    b3ShapeId shapeIdB;
    b3ContactId contactId; /// Transient contact id. Use b3Contact_IsValid before using this id.
}

/// Generated when two shapes stop touching. The shapes and contact may have been
/// destroyed; confirm with `b3Shape_IsValid`/`b3Contact_IsValid` before use.
struct b3ContactEndTouchEvent
{
    b3ShapeId shapeIdA;
    b3ShapeId shapeIdB;
    b3ContactId contactId;
}

/// Generated when two shapes collide faster than the hit speed threshold.
struct b3ContactHitEvent
{
    b3ShapeId shapeIdA;
    b3ShapeId shapeIdB;
    b3ContactId contactId;
    b3Pos point; /// Point where the shapes hit at the beginning of the time step.
    b3Vec3 normal; /// Normal vector pointing from shape A to shape B.
    float approachSpeed = 0; /// The speed the shapes are approaching. Always positive.
    ulong userMaterialIdA; /// User material on shape A.
    ulong userMaterialIdB; /// User material on shape B.
}

/// Contact events buffered in the world, available after the time step.
struct b3ContactEvents
{
    b3ContactBeginTouchEvent* beginEvents;
    b3ContactEndTouchEvent* endEvents;
    b3ContactHitEvent* hitEvents;
    int beginCount;
    int endCount;
    int hitCount;
}

/// Triggered when a body moves due to simulation. Not reported for bodies moved
/// by the user.
struct b3BodyMoveEvent
{
    void* userData;
    b3WorldTransform transform;
    b3BodyId bodyId;
    bool fellAsleep;
}

/// Body events buffered in the world, available after the time step.
struct b3BodyEvents
{
    b3BodyMoveEvent* moveEvents;
    int moveCount;
}

/// Reports joints that are awake and exceed the force and/or torque threshold.
struct b3JointEvent
{
    b3JointId jointId;
    void* userData;
}

/// Joint events buffered in the world, available after the time step.
struct b3JointEvents
{
    b3JointEvent* jointEvents;
    int count;
}

/// The contact data for two shapes. The manifold normal points from shape A to shape B.
struct b3ContactData
{
    b3ContactId contactId; /// May become orphaned. Use b3Contact_IsValid before reuse.
    b3ShapeId shapeIdA;
    b3ShapeId shapeIdB;
    const(b3Manifold)* manifolds; /// Points to internal data and may become invalid. Do not store.
    int manifoldCount; /// Mesh and height-field collision can produce multiple manifolds.
}

// ---------------------------------------------------------------------------
// Query
// ---------------------------------------------------------------------------

/// The query filter is used to filter collisions between queries and shapes.
struct b3QueryFilter
{
    ulong categoryBits; /// The collision category bits of this query.
    ulong maskBits; /// The shape categories this query accepts for collision.
    ulong id; /// Optional id combined with `name` to identify this query in a recording. Ignored when not recording.
    const(char)* name; /// Optional label combined with `id` to identify this query. Ignored when not recording.
}

/// Low level ray cast input data.
struct b3RayCastInput
{
    b3Vec3 origin; /// Start point of the ray cast.
    b3Vec3 translation; /// Translation of the ray cast: end = start + translation.
    float maxFraction = 0; /// The maximum fraction of the translation to consider, typically 1.
}

/// Result from `b3World_RayCastClosest`.
struct b3RayResult
{
    b3ShapeId shapeId;
    b3Pos point;
    b3Vec3 normal;
    ulong userMaterialId; /// Can be per triangle for mesh, height-field, or compound with child mesh.
    float fraction = 0;
    int triangleIndex; /// The triangle index for mesh, height-field, or compound with child mesh.
    int childIndex; /// The child index if the shape is a compound.
    int nodeVisits;
    int leafVisits;
    bool hit; /// If false, all other data is invalid.
}

/// A shape proxy is used by the GJK algorithm. It can represent a convex shape.
struct b3ShapeProxy
{
    const(b3Vec3)* points; /// The point cloud.
    int count; /// The number of points. Do not exceed B3_MAX_SHAPE_CAST_POINTS.
    float radius = 0; /// The external radius of the point cloud.
}

/// Low level shape cast input in generic form. This allows casting an arbitrary
/// point cloud wrap with a radius.
struct b3ShapeCastInput
{
    b3ShapeProxy proxy; /// A generic query shape.
    b3Vec3 translation; /// The translation of the shape cast.
    float maxFraction = 0; /// The maximum fraction of the translation to consider, typically 1.
    bool canEncroach; /// Allow encroachment when initially touching. Requires a radius greater than zero.
}

/// Input for sweeping an AABB through a dynamic tree. The box is in the tree's
/// world float frame; the caller folds the cast shape radius and any world origin
/// into the box.
struct b3BoxCastInput
{
    b3AABB box; /// The AABB to cast, in the tree's frame.
    b3Vec3 translation; /// The sweep translation.
    float maxFraction = 0; /// The maximum fraction of the translation to consider, typically 1.
}

/// Low level ray cast or shape-cast output data.
struct b3CastOutput
{
    b3Vec3 normal; /// The surface normal at the hit point.
    b3Vec3 point; /// The surface hit point.
    float fraction = 0; /// The fraction of the input translation at collision.
    int iterations; /// The number of iterations used.
    int triangleIndex; /// The index of the mesh or height field triangle hit.
    int childIndex; /// The index of the compound child shape.
    int materialIndex; /// The material index. May be -1 for null.
    bool hit;
}

/// Ray cast or shape-cast output in world space. Same type in single precision.
alias b3WorldCastOutput = b3CastOutput;

/// Body cast result for ray and shape casts.
struct b3BodyCastResult
{
    b3ShapeId shapeId;
    b3Pos point; /// The world point on the shape surface.
    b3Vec3 normal; /// The world normal vector on the shape surface.
    float fraction = 0; /// hit point = origin + fraction * translation.
    int triangleIndex; /// The triangle index if the shape is a mesh or height-field.
    ulong userMaterialId; /// Can be per triangle for mesh, height-field, or compound with child mesh.
    int iterations; /// The number of iterations used. Diagnostic.
    bool hit; /// If false, all other fields are invalid.
}

/// Used to warm start the GJK simplex. Users should generally just zero
/// initialize this structure for each call.
struct b3SimplexCache
{
    float metric = 0; /// Value used to compare length, area, volume of two simplexes.
    ushort count; /// The number of stored simplex points.
    ubyte[4] indexA; /// The cached simplex indices on shape A.
    ubyte[4] indexB; /// The cached simplex indices on shape B.
}

/// An empty simplex cache for initializing GJK queries.
enum b3SimplexCache b3_emptyDistanceCache = b3SimplexCache.init;

/// Input parameters for `b3ShapeCast`.
struct b3ShapeCastPairInput
{
    b3ShapeProxy proxyA; /// The proxy for shape A.
    b3ShapeProxy proxyB; /// The proxy for shape B.
    b3Transform transform; /// Transform of shape B in shape A's frame, the relative pose B in A.
    b3Vec3 translationB; /// The translation of shape B, in A's frame.
    float maxFraction = 0; /// The fraction of the translation to consider, typically 1.
    bool canEncroach; /// Allows shapes with a radius to move slightly closer if already touching.
}

/// Input for `b3ShapeDistance`.
struct b3DistanceInput
{
    b3ShapeProxy proxyA; /// The proxy for shape A.
    b3ShapeProxy proxyB; /// The proxy for shape B.
    b3Transform transform; /// Transform of shape B in shape A's frame. The query runs in frame A.
    bool useRadii; /// Should the proxy radius be considered?
}

/// Output for `b3ShapeDistance`.
struct b3DistanceOutput
{
    b3Vec3 pointA; /// Closest point on shapeA, in shape A's frame.
    b3Vec3 pointB; /// Closest point on shapeB, in shape A's frame.
    b3Vec3 normal; /// A to B normal in shape A's frame. Invalid if distance is zero.
    float distance = 0; /// The final distance, zero if overlapped.
    int iterations; /// Number of GJK iterations used.
    int simplexCount; /// The number of simplexes stored in the simplex array.
}

/// Simplex vertex for debugging the GJK algorithm.
struct b3SimplexVertex
{
    b3Vec3 wA; /// support point in proxyA
    b3Vec3 wB; /// support point in proxyB
    b3Vec3 w; /// wB - wA
    float a = 0; /// barycentric coordinates
    int indexA; /// wA index
    int indexB; /// wB index
}

/// Simplex from the GJK algorithm.
struct b3Simplex
{
    b3SimplexVertex[4] vertices; /// vertices
    int count; /// number of valid vertices
}

/// This describes the motion of a body/shape for TOI computation. Shapes are
/// defined with respect to the body origin, which may not coincide with the
/// center of mass.
struct b3Sweep
{
    b3Vec3 localCenter; /// Local center of mass position
    b3Vec3 c1; /// Starting center of mass world position
    b3Vec3 c2; /// Ending center of mass world position
    b3Quat q1; /// Starting world rotation
    b3Quat q2; /// Ending world rotation
}

/// Time of impact input.
struct b3TOIInput
{
    b3ShapeProxy proxyA; /// The proxy for shape A
    b3ShapeProxy proxyB; /// The proxy for shape B
    b3Sweep sweepA; /// The movement of shape A
    b3Sweep sweepB; /// The movement of shape B
    float maxFraction = 0; /// Defines the sweep interval [0, tMax]
}

/// Describes the TOI output.
enum b3TOIState
{
    b3_toiStateUnknown,
    b3_toiStateFailed,
    b3_toiStateOverlapped,
    b3_toiStateHit,
    b3_toiStateSeparated,
}

/// Time of impact output.
struct b3TOIOutput
{
    b3TOIState state; /// The type of result.
    b3Vec3 point; /// The hit point.
    b3Vec3 normal; /// The hit normal.
    float fraction = 0; /// The sweep time of the collision.
    float distance = 0; /// The final distance.
    int distanceIterations; /// Number of outer iterations.
    int pushBackIterations; /// Total number of push back iterations.
    int rootIterations; /// Total number of root iterations.
    bool usedFallback; /// Initial overlap was detected and a fallback sphere was used to prevent tunneling.
}

// ---------------------------------------------------------------------------
// Dynamic tree
// ---------------------------------------------------------------------------

/// Flags for tree nodes. For internal usage.
enum b3TreeNodeFlags
{
    b3_allocatedNode = 0x0001,
    b3_enlargedNode = 0x0002,
    b3_leafNode = 0x0004,
}

/// Tree node child indices. For internal usage.
struct b3TreeNodeChildren
{
    int child1; /// child node index 1
    int child2; /// child node index 2
}

/// A node in the dynamic tree. This is private data placed here for performance reasons.
struct b3TreeNode
{
    b3AABB aabb; /// The node bounding box
    ulong categoryBits; /// Category bits for collision filtering
    union
    {
        b3TreeNodeChildren children; /// Children (internal node)
        ulong userData; /// User data (leaf node)
    }

    union
    {
        int parent; /// The node parent index (allocated node)
        int next; /// The node freelist next index (free node)
    }

    ushort height; /// Height of the node. Leaves have a height of 0.
    ushort flags; /// See b3TreeNodeFlags.
}

/// Dynamic tree version for compatibility testing.
enum ulong B3_DYNAMIC_TREE_VERSION = 0x93EDAF889FD30B4A;

/// The dynamic tree structure. This should be considered private data.
/// It is placed here for performance reasons.
struct b3DynamicTree
{
    ulong version_; /// The dynamic tree version, always the first field. Named `version` in C.
    b3TreeNode* nodes; /// The tree nodes
    int root; /// The root index
    int nodeCount; /// The number of nodes
    int nodeCapacity; /// The allocated node space
    int proxyCount; /// Number of proxies created
    int freeList; /// Node free list
    int* leafIndices; /// Leaf indices for rebuild
    b3AABB* leafBoxes; /// Leaf bounding boxes for rebuild
    b3Vec3* leafCenters; /// Leaf bounding box centers for rebuild
    int* binIndices; /// Bins for sorting during rebuild
    int rebuildCapacity; /// Allocated space for rebuilding
}

/// These are performance results returned by dynamic tree queries.
struct b3TreeStats
{
    int nodeVisits; /// Number of internal nodes visited during the query
    int leafVisits; /// Number of leaf nodes visited during the query
}

/// Receives proxies found in an AABB query. Return true if the query should continue.
alias b3TreeQueryCallbackFcn = bool function(int proxyId, ulong userData, void* context);

/// Receives the minimum distance squared so far and a proxy to check in the closest
/// query. Return the minimum distance squared to user objects in the proxy.
alias b3TreeQueryClosestCallbackFcn = float function(float distanceSqrMin, int proxyId, ulong userData, void* context);

/// Receives clipped AABB cast input for a proxy. Return 0 to terminate, a value less
/// than `input.maxFraction` to clip, or `input.maxFraction` to continue without clipping.
alias b3TreeBoxCastCallbackFcn = float function(const(b3BoxCastInput)* input, int proxyId, ulong userData, void* context);

/// Receives clipped ray cast input for a proxy. Return 0 to terminate, a value less
/// than `input.maxFraction` to clip, or `input.maxFraction` to continue without clipping.
alias b3TreeRayCastCallbackFcn = float function(const(b3RayCastInput)* input, int proxyId, ulong userData, void* context);

// ---------------------------------------------------------------------------
// Character mover
// ---------------------------------------------------------------------------

/// The plane between a character mover and a shape.
struct b3PlaneResult
{
    b3Plane plane; /// Outward pointing plane.
    b3Vec3 point; /// Closest point on the shape. May not be unique.
}

/// Collision planes that can be fed to `b3SolvePlanes`. Normally assembled by the
/// user from plane results in b3PlaneResult.
struct b3CollisionPlane
{
    b3Plane plane; /// The collision plane between the mover and some shape.
    float pushLimit = 0; /// FLT_MAX makes the plane as rigid as possible; lower values soften it. Usually in meters.
    float push = 0; /// The push on the mover determined by b3SolvePlanes. Usually in meters.
    bool clipVelocity; /// Whether b3ClipVector should clip against this plane. Should be false for soft collision.
}

/// Result returned by `b3SolvePlanes`.
struct b3PlaneSolverResult
{
    b3Vec3 delta; /// The final relative translation.
    int iterationCount; /// The number of iterations used by the plane solver. For diagnostics.
}

/// Body plane result for movers.
struct b3BodyPlaneResult
{
    b3ShapeId shapeId; /// The shape id on the body.
    b3PlaneResult result; /// The plane result.
}

/// Collects collision planes for character movers. Return true to continue gathering planes.
alias b3PlaneResultFcn = bool function(b3ShapeId shapeId, const(b3PlaneResult)* plane, int planeCount, void* context);

/// Filters shapes for shape casting character movers. Return true to accept the collision.
alias b3MoverFilterFcn = bool function(b3ShapeId shapeId, void* context);

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// This holds the mass data computed for a shape.
struct b3MassData
{
    float mass = 0; /// The shape mass.
    b3Vec3 center; /// The local center of mass position.
    b3Matrix3 inertia; /// The inertia tensor about the shape center of mass.
}

/// A solid sphere.
struct b3Sphere
{
    b3Vec3 center; /// The local center
    float radius = 0; /// The radius
}

/// A solid capsule can be viewed as two hemispheres connected by a rectangle.
struct b3Capsule
{
    b3Vec3 center1; /// Local center of the first hemisphere
    b3Vec3 center2; /// Local center of the second hemisphere
    float radius = 0; /// The radius of the hemispheres
}

/// A hull vertex. Identified by a half-edge with this vertex as its tail.
struct b3HullVertex
{
    ubyte edge; /// A half-edge that has this vertex as the origin.
}

/// Half-edge for hull data structure.
struct b3HullHalfEdge
{
    ubyte next; /// Next edge index CCW
    ubyte twin; /// Twin edge index
    ubyte origin; /// index of origin vertex and point
    ubyte face; /// Face to the left of this edge
}

/// A hull face. Hulls use a half-edge data structure, so a face can be determined
/// from a single half-edge index.
struct b3HullFace
{
    ubyte edge; /// An arbitrary half-edge on this face.
}

/// 64-bit hull version. Useful for validating serialized data.
enum ulong B3_HULL_VERSION = 0x9D4716CE3793900E;

/// A convex hull.
/// Note: this data structure has data hanging off the end and cannot be directly copied.
struct b3HullData
{
    ulong version_; /// Version must be first and match B3_HULL_VERSION. Named `version` in C.
    int byteCount; /// The total number of bytes for this hull.
    uint hash; /// Hash of this hull (this field is zero when the hash is computed).
    b3AABB aabb; /// Axis-aligned box in local space.
    float surfaceArea = 0; /// Surface area, typically in squared meters.
    float volume = 0; /// Volume, typically in m^3.
    float innerRadius = 0; /// The radius of the largest sphere at the center.
    b3Vec3 center; /// The local centroid.
    b3Matrix3 centralInertia; /// The inertia tensor about the centroid.
    int vertexCount; /// The vertex count.
    int vertexOffset; /// Offset of the vertex array in bytes from the struct address.
    int pointOffset; /// Offset of the point array in bytes from the struct address.
    int edgeCount; /// This is the half-edge count (double the edge count).
    int edgeOffset; /// Offset of the edge array in bytes from the struct address.
    int faceCount; /// The face count. Hull faces are convex polygons.
    int faceOffset; /// Offset of the face array in bytes from the struct address.
    int planeOffset; /// Offset of the face plane array in bytes from the struct address.
    int padding; /// Explicit padding. Hull identity is a content hash over raw bytes.
}

/// Efficient box hull.
struct b3BoxHull
{
    b3HullData base; /// The embedded hull. The offsets index into the arrays that follow.
    b3HullVertex[8] boxVertices; /// Box vertices.
    b3Vec3[8] boxPoints; /// Box points.
    b3HullHalfEdge[24] boxEdges; /// Box half-edges.
    b3HullFace[6] boxFaces; /// Box faces.
    ubyte[2] padding; /// Explicit padding, see b3HullData.padding.
    b3Plane[6] boxPlanes; /// Box face planes.
}

/// This is used to create a re-usable collision mesh.
struct b3MeshDef
{
    b3Vec3* vertices; /// Triangle vertices.
    int* indices; /// Triangle vertex indices. 3 for each triangle.
    ubyte* materialIndices; /// Triangle material index. 1 per triangle. Indexes into b3ShapeDef.materials.
    float weldTolerance = 0; /// Tolerance for vertex welding in length units.
    int vertexCount; /// The vertex count. Must be 3 or more.
    int triangleCount; /// The triangle count. Must be 1 or more.
    bool weldVertices; /// Optionally weld nearby vertices.
    bool useMedianSplit; /// Use the median split instead of SAH to speed up mesh creation.
    bool identifyEdges; /// Compute triangle adjacency information using shared edges.
}

/// 64-bit mesh version. Useful for validating serialized data.
enum ulong B3_MESH_VERSION = 0xABD11AB62A6E886D;

/// Triangle mesh edge flags.
enum b3MeshEdgeFlags
{
    b3_concaveEdge1 = 0x01,
    b3_concaveEdge2 = 0x02,
    b3_concaveEdge3 = 0x04,

    b3_inverseConcaveEdge1 = 0x10,
    b3_inverseConcaveEdge2 = 0x20,
    b3_inverseConcaveEdge3 = 0x40,

    b3_allConcaveEdges = b3_concaveEdge1 | b3_concaveEdge2 | b3_concaveEdge3,

    b3_flatEdge1 = b3_concaveEdge1 | b3_inverseConcaveEdge1,
    b3_flatEdge2 = b3_concaveEdge2 | b3_inverseConcaveEdge2,
    b3_flatEdge3 = b3_concaveEdge3 | b3_inverseConcaveEdge3,

    b3_allFlatEdges = b3_flatEdge1 | b3_flatEdge2 | b3_flatEdge3,
}

/// A mesh triangle.
struct b3MeshTriangle
{
    int index1; /// Index of vertex 1.
    int index2; /// Index of vertex 2.
    int index3; /// Index of vertex 3.
}

/// A mesh BVH node.
struct b3MeshNode
{
    /// The lower bound of the node AABB. Strategic placement for SIMD.
    b3Vec3 lowerBound;

    /// Packed node data. In C this is a union (named `data`) of two bitfield structs
    /// sharing one 32-bit word. Internal node (`asNode`): bits 0-1 = split axis
    /// (0, 1, or 2), bits 2-31 = offset of the second child node. Leaf node
    /// (`asLeaf`): bits 0-1 = type tag (3 for a leaf), bits 2-31 = the number of
    /// triangles for this leaf node.
    uint data;

    /// The upper bound of the node AABB. Strategic placement for SIMD.
    b3Vec3 upperBound;

    /// The index of the leaf triangles.
    uint triangleOffset;
}

/// This is a sorted triangle collision bounding volume hierarchy.
/// Note: this struct has data hanging off the end and cannot be directly copied.
struct b3MeshData
{
    ulong version_; /// Version must be first. Named `version` in C.
    int byteCount; /// The total number of bytes for this mesh.
    uint hash; /// Hash of this mesh (this field is zero when the hash is computed).
    b3AABB bounds; /// Local axis-aligned box.
    float surfaceArea = 0; /// Combined surface area of all triangles. Single-sided.
    int treeHeight; /// The height of the bounding volume hierarchy.
    int degenerateCount; /// The number of degenerate triangles. Diagnostic.
    int nodeOffset; /// Offset of the node array in bytes from the struct address.
    int nodeCount; /// The number of BVH nodes.
    int vertexOffset; /// Offset of the vertex array in bytes from the struct address.
    int vertexCount; /// The number of vertices.
    int triangleOffset; /// Offset of the triangle array in bytes from the struct address.
    int triangleCount; /// The number of triangles.
    int materialOffset; /// Offset of the material array in bytes from the struct address.
    int materialCount; /// The number of materials.
    int flagsOffset; /// Offset of the triangle flag array in bytes from the struct address.
}

/// This allows mesh data to be re-used with different scales.
struct b3Mesh
{
    const(b3MeshData)* data; /// Immutable pointer to the mesh data.
    b3Vec3 scale; /// May be non-uniform and have negative components, but no tiny components.
}

/// Data used to create a height field.
struct b3HeightFieldDef
{
    float* heights; /// Grid point heights. count = countX * countZ.
    ubyte* materialIndices; /// Grid cell material. 0xFF is reserved for holes. count = (countX - 1) * (countZ - 1).
    b3Vec3 scale; /// The height field scale. All components must be positive values.
    int countX; /// The number of grid lines along the x-axis.
    int countZ; /// The number of grid lines along the z-axis.
    float globalMinimumHeight = 0; /// Global minimum height used for quantization, in unscaled space.
    float globalMaximumHeight = 0; /// Global maximum height used for quantization, in unscaled space.
    bool clockwiseWinding; /// Use clock-wise winding. Effectively inverts the height-field along the y-axis.
}

/// This material index is used to designate holes in a height field.
enum ubyte B3_HEIGHT_FIELD_HOLE = 0xFF;

/// 64-bit height-field version. Useful for validating serialized data.
enum ulong B3_HEIGHT_FIELD_VERSION = 0x8B18CBD138A6BC84;

/// A height field with compressed storage.
/// Note: this data structure has data hanging off the end and cannot be directly copied.
struct b3HeightFieldData
{
    ulong version_; /// Version must be first and match B3_HEIGHT_FIELD_VERSION. Named `version` in C.
    int byteCount; /// The total number of bytes for this height field.
    uint hash; /// Hash of this height field (this field is zero when the hash is computed).
    b3AABB aabb; /// The local axis-aligned bounding box.
    float minHeight = 0; /// The minimum y value.
    float maxHeight = 0; /// The maximum y value.
    float heightScale = 0; /// The quantization scale.
    b3Vec3 scale; /// The overall scale.
    int columnCount; /// The number of grid columns along the local x-axis.
    int rowCount; /// The number of grid rows along the local z-axis.
    int heightsOffset; /// Offset of the compressed height array (ushort per grid point) in bytes from the struct address.
    int materialOffset; /// Offset of the material index array (ubyte per cell) in bytes from the struct address.
    int flagsOffset; /// Offset of the flag array (ubyte per triangle) in bytes from the struct address.
    bool clockwise; /// Triangle winding.
    ubyte[3] padding; /// Explicit padding. Identity is a content hash over raw bytes.
}

// ---------------------------------------------------------------------------
// Compound
// ---------------------------------------------------------------------------

/// Definition for a capsule in a compound shape.
struct b3CompoundCapsuleDef
{
    b3Capsule capsule; /// Local capsule.
    b3SurfaceMaterial material; /// Material properties.
}

/// Definition for a convex hull in a compound shape.
struct b3CompoundHullDef
{
    const(b3HullData)* hull; /// Shared hull.
    b3Transform transform; /// Transform of the shared hull into compound local space.
    b3SurfaceMaterial material; /// Material properties.
}

/// Definition for a triangle mesh in a compound shape.
struct b3CompoundMeshDef
{
    const(b3MeshData)* meshData; /// Shared mesh.
    b3Transform transform; /// Transform of the shared mesh into compound local space.
    b3Vec3 scale; /// Local space non-uniform mesh scale. May have negative components.
    const(b3SurfaceMaterial)* materials; /// Must line up with the material indices on the triangles.
    int materialCount; /// Number of materials.
}

/// Definition for a sphere in a compound shape.
struct b3CompoundSphereDef
{
    b3Sphere sphere; /// Local sphere.
    b3SurfaceMaterial material; /// Material properties.
}

/// Definition for creating a compound shape. All this data is fully cloned into
/// the run-time compound shape.
struct b3CompoundDef
{
    b3CompoundCapsuleDef* capsules; /// Capsule instances.
    int capsuleCount; /// Number of capsules.
    b3CompoundHullDef* hulls; /// Hull instances.
    int hullCount; /// Number of hull instances.
    b3CompoundMeshDef* meshes; /// Mesh instances.
    int meshCount; /// Number of mesh instances.
    b3CompoundSphereDef* spheres; /// Sphere instances.
    int sphereCount; /// Number of spheres.
}

/// The compound version depends on the tree, mesh, and hull versions.
enum ulong B3_COMPOUND_VERSION = 0x830778DB07086EB4 ^ B3_DYNAMIC_TREE_VERSION ^ B3_MESH_VERSION ^ B3_HULL_VERSION;

/// Meshes used in compounds have limited space for materials. If you have a mesh
/// with many materials, you can use it outside of the compound.
enum int B3_MAX_COMPOUND_MESH_MATERIALS = 4;

/// The runtime data for a compound shape. This is a potentially large yet highly
/// optimized data structure that populates into the world as a single shape.
/// Note: this data structure has data living off the end and must be accessed
/// using offsets. Accessors are provided for user relevant data.
struct b3CompoundData
{
    ulong version_; /// The compound version is always first. Named `version` in C.
    int byteCount; /// The total number of bytes for this compound.
    int nodeOffset; /// Offset of the tree node array in bytes from the struct address.
    b3DynamicTree tree; /// Immutable dynamic tree. The node pointer must be fixed up using the node offset.
    int materialOffset; /// Offset of the material array in bytes from the struct address.
    int materialCount; /// The number of materials.
    int capsuleOffset; /// Offset of the capsule array in bytes from the struct address.
    int capsuleCount; /// The number of capsules.
    int hullOffset; /// Offset of the hull instance array in bytes from the struct address.
    int hullCount; /// The number of hull instances.
    int sharedHullCount; /// The number of unique hulls. Diagnostic.
    int meshOffset; /// Offset of the mesh instance array in bytes from the struct address.
    int meshCount; /// The number of mesh instances.
    int sharedMeshCount; /// The number of unique meshes. Diagnostic.
    int sphereOffset; /// Offset of the sphere array in bytes from the struct address.
    int sphereCount; /// The number of spheres.
}

/// A capsule that lives in a compound.
struct b3CompoundCapsule
{
    b3Capsule capsule; /// Local capsule.
    int materialIndex; /// Index to a shared material.
}

/// A hull that lives in a compound.
struct b3CompoundHull
{
    const(b3HullData)* hull; /// Pointer to the unique shared hull.
    b3Transform transform; /// The transform of this hull instance.
    int materialIndex; /// Index to a shared material.
}

/// A mesh with non-uniform scale that lives in a compound.
struct b3CompoundMesh
{
    const(b3MeshData)* meshData; /// Pointer to the unique shared mesh.
    b3Transform transform; /// The transform of this mesh instance.
    b3Vec3 scale; /// Non-uniform scale of this mesh instance.

    /// Used to access the surface material from b3GetCompoundMaterials:
    /// materialIndex = materialIndices[triangle.materialIndex].
    int[B3_MAX_COMPOUND_MESH_MATERIALS] materialIndices;
}

/// A sphere that lives in a compound.
struct b3CompoundSphere
{
    b3Sphere sphere; /// Local sphere.
    int materialIndex; /// Index to a shared material.
}

/// Child shape of a compound.
struct b3ChildShape
{
    /// Tagged union.
    union
    {
        b3Capsule capsule; /// Capsule.
        const(b3HullData)* hull; /// Hull.
        b3Mesh mesh; /// Mesh.
        b3Sphere sphere; /// Sphere.
        // C pads the union's size to a multiple of its 8-byte alignment
        // (from the pointer member); D does not, so pad explicitly.
        ubyte[32] cUnionPadding;
    }

    b3Transform transform; /// Transform of the shape into compound local space.
    int[B3_MAX_COMPOUND_MESH_MATERIALS] materialIndices; /// Material indices. Index 0 is used for convex shapes.
    b3ShapeType type; /// The shape type (union tag).
}

/// Callback for compound overlap queries.
alias b3CompoundQueryFcn = bool function(const(b3CompoundData)* compound, int childIndex, void* context);

// ---------------------------------------------------------------------------
// Shape collision
// ---------------------------------------------------------------------------

/// A manifold point is a contact point belonging to a contact manifold.
/// Box3D uses speculative collision so some contact points may be separated.
/// You may use `totalNormalImpulse` to determine if there was an interaction
/// during the time step.
struct b3ManifoldPoint
{
    b3Vec3 anchorA; /// Contact point relative to the bodyA center of mass in world space.
    b3Vec3 anchorB; /// Contact point relative to the bodyB center of mass in world space.
    float separation = 0; /// The separation of the contact point, negative if penetrating.
    float baseSeparation = 0; /// Cached separation used for contact recycling.
    float normalImpulse = 0; /// The impulse along the manifold normal from the final sub-step.
    float totalNormalImpulse = 0; /// The total normal impulse applied during sub-stepping.
    float normalVelocity = 0; /// Relative normal velocity pre-solve. Negative means shapes are approaching.
    uint featureId; /// Uniquely identifies a contact point between two shapes.
    int triangleIndex; /// Triangle index if one of the shapes is a mesh or height field.
    bool persisted; /// Did this contact point exist in the previous step?
}

/// A contact manifold describes the contact points between colliding shapes.
/// Note: Box3D uses speculative collision so some contact points may be separated.
struct b3Manifold
{
    b3ManifoldPoint[B3_MAX_MANIFOLD_POINTS] points; /// The manifold points. There may be 1 to 4 valid points.
    b3Vec3 normal; /// The unit normal vector in world space, points from shape A to shape B.
    float twistImpulse = 0; /// Central friction angular impulse (applied about the normal).
    b3Vec3 frictionImpulse; /// Central friction linear impulse.
    b3Vec3 rollingImpulse; /// Rolling resistance angular impulse.
    int pointCount; /// The number of contact points, will be 0 to 4.
}

/// Cached separating axis feature.
enum b3SeparatingFeature
{
    b3_invalidAxis = 0,
    b3_backsideAxis,
    b3_faceAxisA,
    b3_faceAxisB,
    b3_edgePairAxis,
    b3_closestPointsAxis,

    b3_manualFaceAxisA, /// For testing.
    b3_manualFaceAxisB, /// For testing.
    b3_manualEdgePairAxis, /// For testing.
}

/// Cached triangle feature.
enum b3TriangleFeature
{
    b3_featureNone = 0,
    b3_featureTriangleFace,
    b3_featureHullFace,
    b3_featureEdge1, /// v1-v2
    b3_featureEdge2, /// v2-v3
    b3_featureEdge3, /// v3-v1
    b3_featureVertex1,
    b3_featureVertex2,
    b3_featureVertex3,
}

/// Separating axis test cache. Provides temporal acceleration of collision routines.
struct b3SATCache
{
    float separation = 0; /// The separation when the cache is populated. Negative for overlap.
    ubyte type; /// b3SeparatingFeature.
    ubyte indexA; /// Index of the feature on shape A.
    ubyte indexB; /// Index of the feature on shape B.
    ubyte hit; /// Was the cache re-used?
}

/// Contact points are always the result of two edges intersecting, possibly from
/// different shapes. The feature pair is used to identify contact points for
/// temporal coherence and warm starting.
struct b3FeaturePair
{
    ubyte owner1; /// Incoming type (either edge on shape A or shape B)
    ubyte index1; /// Incoming edge index (into associated shape array)
    ubyte owner2; /// Outgoing type (either edge on shape A or shape B)
    ubyte index2; /// Outgoing edge index (into associated shape array)
}

/// A local manifold point and normal in frame A.
struct b3LocalManifoldPoint
{
    b3Vec3 point; /// Local point in frame A.
    float separation = 0; /// The contact point separation. Negative for overlap.
    b3FeaturePair pair; /// The feature pair for this point.
    int triangleIndex; /// The triangle index when colliding with a mesh or height-field.
}

/// A local manifold with no dynamic information. Used by b3Collide functions.
struct b3LocalManifold
{
    b3Vec3 normal; /// Local normal in frame A.
    b3Vec3 triangleNormal; /// The triangle normal.
    b3LocalManifoldPoint* points; /// The manifold points. From a point buffer.
    int pointCount; /// The number of manifold points. Only bounded by the buffer capacity.
    int triangleIndex; /// The index of the triangle.
    int i1; /// Vertex 1 index.
    int i2; /// Vertex 2 index.
    int i3; /// Vertex 3 index.
    float squaredDistance = 0; /// Squared distance of a sphere from a triangle. For ghost collision reduction.
    b3TriangleFeature feature; /// The triangle feature involved.
    int triangleFlags; /// b3MeshEdgeFlags.
}

// ---------------------------------------------------------------------------
// Debug draw
// ---------------------------------------------------------------------------

/// Named colors for debug draw, mostly matching the named SVG colors.
enum b3HexColor
{
    b3_colorAliceBlue = 0xF0F8FF,
    b3_colorAntiqueWhite = 0xFAEBD7,
    b3_colorAqua = 0x00FFFF,
    b3_colorAquamarine = 0x7FFFD4,
    b3_colorAzure = 0xF0FFFF,
    b3_colorBeige = 0xF5F5DC,
    b3_colorBisque = 0xFFE4C4,
    b3_colorBlack = 0x000000,
    b3_colorBlanchedAlmond = 0xFFEBCD,
    b3_colorBlue = 0x0000FF,
    b3_colorBlueViolet = 0x8A2BE2,
    b3_colorBrown = 0xA52A2A,
    b3_colorBurlywood = 0xDEB887,
    b3_colorCadetBlue = 0x5F9EA0,
    b3_colorChartreuse = 0x7FFF00,
    b3_colorChocolate = 0xD2691E,
    b3_colorCoral = 0xFF7F50,
    b3_colorCornflowerBlue = 0x6495ED,
    b3_colorCornsilk = 0xFFF8DC,
    b3_colorCrimson = 0xDC143C,
    b3_colorCyan = 0x00FFFF,
    b3_colorDarkBlue = 0x00008B,
    b3_colorDarkCyan = 0x008B8B,
    b3_colorDarkGoldenRod = 0xB8860B,
    b3_colorDarkGray = 0xA9A9A9,
    b3_colorDarkGreen = 0x006400,
    b3_colorDarkKhaki = 0xBDB76B,
    b3_colorDarkMagenta = 0x8B008B,
    b3_colorDarkOliveGreen = 0x556B2F,
    b3_colorDarkOrange = 0xFF8C00,
    b3_colorDarkOrchid = 0x9932CC,
    b3_colorDarkRed = 0x8B0000,
    b3_colorDarkSalmon = 0xE9967A,
    b3_colorDarkSeaGreen = 0x8FBC8F,
    b3_colorDarkSlateBlue = 0x483D8B,
    b3_colorDarkSlateGray = 0x2F4F4F,
    b3_colorDarkTurquoise = 0x00CED1,
    b3_colorDarkViolet = 0x9400D3,
    b3_colorDeepPink = 0xFF1493,
    b3_colorDeepSkyBlue = 0x00BFFF,
    b3_colorDimGray = 0x696969,
    b3_colorDodgerBlue = 0x1E90FF,
    b3_colorFireBrick = 0xB22222,
    b3_colorFloralWhite = 0xFFFAF0,
    b3_colorForestGreen = 0x228B22,
    b3_colorFuchsia = 0xFF00FF,
    b3_colorGainsboro = 0xDCDCDC,
    b3_colorGhostWhite = 0xF8F8FF,
    b3_colorGold = 0xFFD700,
    b3_colorGoldenRod = 0xDAA520,
    b3_colorGray = 0x808080,
    b3_colorGreen = 0x008000,
    b3_colorGreenYellow = 0xADFF2F,
    b3_colorHoneyDew = 0xF0FFF0,
    b3_colorHotPink = 0xFF69B4,
    b3_colorIndianRed = 0xCD5C5C,
    b3_colorIndigo = 0x4B0082,
    b3_colorIvory = 0xFFFFF0,
    b3_colorKhaki = 0xF0E68C,
    b3_colorLavender = 0xE6E6FA,
    b3_colorLavenderBlush = 0xFFF0F5,
    b3_colorLawnGreen = 0x7CFC00,
    b3_colorLemonChiffon = 0xFFFACD,
    b3_colorLightBlue = 0xADD8E6,
    b3_colorLightCoral = 0xF08080,
    b3_colorLightCyan = 0xE0FFFF,
    b3_colorLightGoldenRodYellow = 0xFAFAD2,
    b3_colorLightGray = 0xD3D3D3,
    b3_colorLightGreen = 0x90EE90,
    b3_colorLightPink = 0xFFB6C1,
    b3_colorLightSalmon = 0xFFA07A,
    b3_colorLightSeaGreen = 0x20B2AA,
    b3_colorLightSkyBlue = 0x87CEFA,
    b3_colorLightSlateGray = 0x778899,
    b3_colorLightSteelBlue = 0xB0C4DE,
    b3_colorLightYellow = 0xFFFFE0,
    b3_colorLime = 0x00FF00,
    b3_colorLimeGreen = 0x32CD32,
    b3_colorLinen = 0xFAF0E6,
    b3_colorMagenta = 0xFF00FF,
    b3_colorMaroon = 0x800000,
    b3_colorMediumAquaMarine = 0x66CDAA,
    b3_colorMediumBlue = 0x0000CD,
    b3_colorMediumOrchid = 0xBA55D3,
    b3_colorMediumPurple = 0x9370DB,
    b3_colorMediumSeaGreen = 0x3CB371,
    b3_colorMediumSlateBlue = 0x7B68EE,
    b3_colorMediumSpringGreen = 0x00FA9A,
    b3_colorMediumTurquoise = 0x48D1CC,
    b3_colorMediumVioletRed = 0xC71585,
    b3_colorMidnightBlue = 0x191970,
    b3_colorMintCream = 0xF5FFFA,
    b3_colorMistyRose = 0xFFE4E1,
    b3_colorMoccasin = 0xFFE4B5,
    b3_colorNavajoWhite = 0xFFDEAD,
    b3_colorNavy = 0x000080,
    b3_colorOldLace = 0xFDF5E6,
    b3_colorOlive = 0x808000,
    b3_colorOliveDrab = 0x6B8E23,
    b3_colorOrange = 0xFFA500,
    b3_colorOrangeRed = 0xFF4500,
    b3_colorOrchid = 0xDA70D6,
    b3_colorPaleGoldenRod = 0xEEE8AA,
    b3_colorPaleGreen = 0x98FB98,
    b3_colorPaleTurquoise = 0xAFEEEE,
    b3_colorPaleVioletRed = 0xDB7093,
    b3_colorPapayaWhip = 0xFFEFD5,
    b3_colorPeachPuff = 0xFFDAB9,
    b3_colorPeru = 0xCD853F,
    b3_colorPink = 0xFFC0CB,
    b3_colorPlum = 0xDDA0DD,
    b3_colorPowderBlue = 0xB0E0E6,
    b3_colorPurple = 0x800080,
    b3_colorRebeccaPurple = 0x663399,
    b3_colorRed = 0xFF0000,
    b3_colorRosyBrown = 0xBC8F8F,
    b3_colorRoyalBlue = 0x4169E1,
    b3_colorSaddleBrown = 0x8B4513,
    b3_colorSalmon = 0xFA8072,
    b3_colorSandyBrown = 0xF4A460,
    b3_colorSeaGreen = 0x2E8B57,
    b3_colorSeaShell = 0xFFF5EE,
    b3_colorSienna = 0xA0522D,
    b3_colorSilver = 0xC0C0C0,
    b3_colorSkyBlue = 0x87CEEB,
    b3_colorSlateBlue = 0x6A5ACD,
    b3_colorSlateGray = 0x708090,
    b3_colorSnow = 0xFFFAFA,
    b3_colorSpringGreen = 0x00FF7F,
    b3_colorSteelBlue = 0x4682B4,
    b3_colorTan = 0xD2B48C,
    b3_colorTeal = 0x008080,
    b3_colorThistle = 0xD8BFD8,
    b3_colorTomato = 0xFF6347,
    b3_colorTurquoise = 0x40E0D0,
    b3_colorViolet = 0xEE82EE,
    b3_colorWheat = 0xF5DEB3,
    b3_colorWhite = 0xFFFFFF,
    b3_colorWhiteSmoke = 0xF5F5F5,
    b3_colorYellow = 0xFFFF00,
    b3_colorYellowGreen = 0x9ACD32,

    b3_colorBox2DRed = 0xDC3132,
    b3_colorBox2DBlue = 0x30AEBF,
    b3_colorBox2DGreen = 0x8CC924,
    b3_colorBox2DYellow = 0xFFEE8C,
}

/// Debug draw material preset. Optionally packed into the unused high byte of a
/// b3HexColor (or `b3SurfaceMaterial.customColor`) to drive the renderer's PBR
/// roughness and metalness. The low 24 bits stay RGB, so a plain 0xRRGGBB color
/// reads as b3_debugMaterialDefault.
enum b3DebugMaterial
{
    b3_debugMaterialDefault = 0,
    b3_debugMaterialMatte,
    b3_debugMaterialSoft,
    b3_debugMaterialDead,
    b3_debugMaterialGlossy,
    b3_debugMaterialMetallic,
}

/// Pack an RGB color with a material preset for debug draw. The preset rides in
/// the high byte where the color converters ignore it.
pragma(inline, true) uint b3MakeDebugColor(b3HexColor rgb, b3DebugMaterial material) => (cast(uint) rgb & 0x00FFFFFF) | (
        cast(uint) material << 24);

/// This is sent to the user for debug shape creation. The user should know the
/// type in case they have custom sphere or capsule rendering.
struct b3DebugShape
{
    b3ShapeId shapeId; /// Shape id.
    b3ShapeType type; /// Shape type (union tag).

    /// Tagged union.
    union
    {
        const(b3Capsule)* capsule; /// Capsule shape.
        const(b3CompoundData)* compound; /// Compound shape.
        const(b3HeightFieldData)* heightField; /// Height-field shape.
        const(b3HullData)* hull; /// Convex hull shape.
        const(b3Mesh)* mesh; /// Mesh shape with scale.
        const(b3Sphere)* sphere; /// Sphere shape.
    }
}

/// This struct is passed to `b3World_Draw` to draw a debug view of the simulation
/// world. Callbacks receive world coordinates. Initialize with `b3DefaultDebugDraw`.
struct b3DebugDraw
{
    /// Draws a shape and returns true if drawing should continue.
    bool function(void* userShape, b3WorldTransform transform, b3HexColor color, void* context) DrawShapeFcn;

    /// Draw a line segment.
    void function(b3Pos p1, b3Pos p2, b3HexColor color, void* context) DrawSegmentFcn;

    /// Draw a transform. Choose your own length scale.
    void function(b3WorldTransform transform, void* context) DrawTransformFcn;

    /// Draw a point.
    void function(b3Pos p, float size, b3HexColor color, void* context) DrawPointFcn;

    /// Draw a sphere.
    void function(b3Pos p, float radius, b3HexColor color, float alpha, void* context) DrawSphereFcn;

    /// Draw a capsule.
    void function(b3Pos p1, b3Pos p2, float radius, b3HexColor color, float alpha, void* context) DrawCapsuleFcn;

    /// Draw a bounding box.
    void function(b3AABB aabb, b3HexColor color, void* context) DrawBoundsFcn;

    /// Draw an oriented box.
    void function(b3Vec3 extents, b3WorldTransform transform, b3HexColor color, void* context) DrawBoxFcn;

    /// Draw a string in world space.
    void function(b3Pos p, const(char)* s, b3HexColor color, void* context) DrawStringFcn;

    b3AABB drawingBounds; /// World bounds to use for debug draw
    float forceScale = 0; /// Scale to use when drawing forces
    float jointScale = 0; /// Global scaling for joint drawing
    bool drawShapes; /// Option to draw shapes
    bool drawJoints; /// Option to draw joints
    bool drawJointExtras; /// Option to draw additional information for joints
    bool drawBounds; /// Option to draw the bounding boxes for shapes
    bool drawMass; /// Option to draw the mass and center of mass of dynamic bodies
    bool drawBodyNames; /// Option to draw body names
    bool drawContacts; /// Option to draw contact points
    int drawAnchorA; /// Draw contact anchor A or B
    bool drawGraphColors; /// Option to visualize the graph coloring used for contacts and joints
    bool drawContactFeatures; /// Option to draw contact features
    bool drawContactNormals; /// Option to draw contact normals
    bool drawContactForces; /// Option to draw contact normal forces
    bool drawFrictionForces; /// Option to draw contact friction forces
    bool drawIslands; /// Option to draw islands as bounding boxes
    void* context; /// User context passed to drawing callback functions
}

// ---------------------------------------------------------------------------
// Default initializers (exported)
// ---------------------------------------------------------------------------

@nogc:

/// Use this to initialize your world definition.
b3WorldDef b3DefaultWorldDef();

/// Use this to initialize your body definition.
b3BodyDef b3DefaultBodyDef();

/// Use this to initialize your collision filter.
b3Filter b3DefaultFilter();

/// Use this to initialize your surface material.
b3SurfaceMaterial b3DefaultSurfaceMaterial();

/// Use this to initialize your shape definition.
b3ShapeDef b3DefaultShapeDef();

/// Use this to initialize your distance joint definition.
b3DistanceJointDef b3DefaultDistanceJointDef();

/// Use this to initialize your motor joint definition.
b3MotorJointDef b3DefaultMotorJointDef();

/// Use this to initialize your filter joint definition.
b3FilterJointDef b3DefaultFilterJointDef();

/// Use this to initialize your parallel joint definition.
b3ParallelJointDef b3DefaultParallelJointDef();

/// Use this to initialize your prismatic joint definition.
b3PrismaticJointDef b3DefaultPrismaticJointDef();

/// Use this to initialize your revolute joint definition.
b3RevoluteJointDef b3DefaultRevoluteJointDef();

/// Use this to initialize your spherical joint definition.
b3SphericalJointDef b3DefaultSphericalJointDef();

/// Use this to initialize your weld joint definition.
b3WeldJointDef b3DefaultWeldJointDef();

/// Use this to initialize your wheel joint definition.
b3WheelJointDef b3DefaultWheelJointDef();

/// Use this to initialize your explosion definition.
b3ExplosionDef b3DefaultExplosionDef();

/// Use this to initialize your query filter.
b3QueryFilter b3DefaultQueryFilter();

/// Get the visualization color assigned to a constraint graph color slot. The last
/// index (B3_GRAPH_COLOR_COUNT - 1) is the overflow color.
b3HexColor b3GetGraphColor(int index);

/// Use this to initialize your drawing interface.
b3DebugDraw b3DefaultDebugDraw();
