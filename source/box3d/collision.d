// SPDX-License-Identifier: MIT
/++
    Dynamic tree, hull, mesh, height field, compound, geometry, query and
    collision functions.

    Translated from `box3d/collision.h`. The header-only `B3_INLINE` helpers are
    reimplemented in D; the remaining `B3_API` functions are `extern(C)` bindings
    into the library.
+/
module box3d.collision;

import box3d.math_functions;
import box3d.types;

@nogc nothrow:

extern (C):

// ---------------------------------------------------------------------------
// Dynamic tree
// ---------------------------------------------------------------------------

/// Construct a dynamic tree, initializing the node pool.
b3DynamicTree b3DynamicTree_Create(int proxyCapacity);

/// Destroy the tree, freeing the node pool.
void b3DynamicTree_Destroy(b3DynamicTree* tree);

/// Create a proxy. Provide an AABB and a userData value.
int b3DynamicTree_CreateProxy(b3DynamicTree* tree, b3AABB aabb, ulong categoryBits, ulong userData);

/// Destroy a proxy. This asserts if the id is invalid.
void b3DynamicTree_DestroyProxy(b3DynamicTree* tree, int proxyId);

/// Move a proxy to a new AABB by removing and reinserting into the tree.
void b3DynamicTree_MoveProxy(b3DynamicTree* tree, int proxyId, b3AABB aabb);

/// Enlarge a proxy and enlarge ancestors as necessary.
void b3DynamicTree_EnlargeProxy(b3DynamicTree* tree, int proxyId, b3AABB aabb);

/// Modify the category bits on a proxy. This is an expensive operation.
void b3DynamicTree_SetCategoryBits(b3DynamicTree* tree, int proxyId, ulong categoryBits);

/// Get the category bits on a proxy.
ulong b3DynamicTree_GetCategoryBits(b3DynamicTree* tree, int proxyId);

/// Query an AABB for overlapping proxies. The callback function is called
/// for each proxy that overlaps the supplied AABB.
/// Returns: performance data
b3TreeStats b3DynamicTree_Query(const(b3DynamicTree)* tree, b3AABB aabb, ulong maskBits, bool requireAllBits,
        b3TreeQueryCallbackFcn callback, void* context);

/// Query an AABB for the closest object. The callback function is called for
/// each proxy that might be closest to the supplied point.
/// Params:
///   tree = the dynamic tree to query
///   point = the query point
///   maskBits = nodes are skipped if the bit-wise AND with the node category bits is zero
///   requireAllBits = nodes are skipped if the bit-wise AND with the node category bits does not equal the maskBits
///   callback = a user provided instance of `b3TreeQueryClosestCallbackFcn`
///   context = a user context object that is provided to the callback
///   minDistanceSqr = the initial and final minimum squared distance. Provide a small
///     initial value to restrict the search and improve performance.
/// Returns: performance data
b3TreeStats b3DynamicTree_QueryClosest(const(b3DynamicTree)* tree, b3Vec3 point, ulong maskBits,
        bool requireAllBits, b3TreeQueryClosestCallbackFcn callback, void* context, float* minDistanceSqr);

/// Ray cast against the proxies in the tree. This relies on the callback to perform
/// an exact ray cast in the case where the proxy contains a shape. The callback also
/// performs any collision filtering.
/// Params:
///   tree = the dynamic tree to ray cast
///   input = the ray cast input data. The ray extends from p1 to p1 + maxFraction * (p2 - p1)
///   maskBits = bit mask test: `bool accept = (maskBits & node.categoryBits) != 0;`
///   requireAllBits = modifies bit mask test: `bool accept = (maskBits & node.categoryBits) == maskBits;`
///   callback = a callback function that is called for each proxy that is hit by the ray
///   context = user context that is passed to the callback
/// Returns: performance data
b3TreeStats b3DynamicTree_RayCast(const(b3DynamicTree)* tree, const(b3RayCastInput)* input, ulong maskBits,
        bool requireAllBits, b3TreeRayCastCallbackFcn callback, void* context);

/// Sweep an AABB through the tree. The box is in the tree's world float frame and the
/// callback re-differences each shape at full precision against the query origin.
b3TreeStats b3DynamicTree_BoxCast(const(b3DynamicTree)* tree, const(b3BoxCastInput)* input, ulong maskBits,
        bool requireAllBits, b3TreeBoxCastCallbackFcn callback, void* context);

/// Validate this tree. For testing.
void b3DynamicTree_Validate(const(b3DynamicTree)* tree);

/// Get the height of the binary tree.
int b3DynamicTree_GetHeight(const(b3DynamicTree)* tree);

/// Get the ratio of the sum of the node areas to the root area.
float b3DynamicTree_GetAreaRatio(const(b3DynamicTree)* tree);

/// Get the bounding box that contains the entire tree.
b3AABB b3DynamicTree_GetRootBounds(const(b3DynamicTree)* tree);

/// Get the number of proxies created.
int b3DynamicTree_GetProxyCount(const(b3DynamicTree)* tree);

/// Rebuild the tree while retaining subtrees that haven't changed. Returns the number of boxes sorted.
int b3DynamicTree_Rebuild(b3DynamicTree* tree, bool fullBuild);

/// Get the number of bytes used by this tree.
int b3DynamicTree_GetByteCount(const(b3DynamicTree)* tree);

/// Validate this tree has no enlarged AABBs. For testing.
void b3DynamicTree_ValidateNoEnlarged(const(b3DynamicTree)* tree);

/// Save this tree to a file for debugging.
void b3DynamicTree_Save(const(b3DynamicTree)* tree, const(char)* fileName);

/// Load a file for debugging.
b3DynamicTree b3DynamicTree_Load(const(char)* fileName, float scale);

// ---------------------------------------------------------------------------
// Convex hull
// ---------------------------------------------------------------------------

/// Create a tessellated cylinder as a hull.
b3HullData* b3CreateCylinder(float height, float radius, float yOffset, int sides);

/// Create a tessellated cone as a hull.
b3HullData* b3CreateCone(float height, float radius1, float radius2, int slices);

/// Create a rock shaped hull.
b3HullData* b3CreateRock(float radius);

/// Create a generic convex hull.
b3HullData* b3CreateHull(const(b3Vec3)* points, int pointCount, int maxVertexCount);

/// Deep clone a hull.
b3HullData* b3CloneHull(const(b3HullData)* hull);

/// Clone and transform a hull. Supports non-uniform and mirroring scale.
b3HullData* b3CloneAndTransformHull(const(b3HullData)* original, b3Transform transform, b3Vec3 scale);

/// Destroy a hull.
void b3DestroyHull(b3HullData* hull);

/// Make a cube as a hull. Do not call `b3DestroyHull` on this.
b3BoxHull b3MakeCubeHull(float halfWidth);

/// Make a box as a hull. Do not call `b3DestroyHull` on this.
b3BoxHull b3MakeBoxHull(float hx, float hy, float hz);

/// Make an offset box as a hull. Do not call `b3DestroyHull` on this.
b3BoxHull b3MakeOffsetBoxHull(float hx, float hy, float hz, b3Vec3 offset);

/// Make a transformed box as a hull. Do not call `b3DestroyHull` on this.
/// Params:
///   hx = positive half width
///   hy = positive half height
///   hz = positive half depth
///   transform = local transform of box
b3BoxHull b3MakeTransformedBoxHull(float hx, float hy, float hz, b3Transform transform);

/// This makes a transformed box hull with post scaling. This is useful for boxes that
/// are scaled in a level editor. Such scaling can have reflection and shear. In the case
/// of shear the result may be approximate. If you need to support shear consider using
/// `b3CreateHull`. Do not call `b3DestroyHull` on this.
/// Params:
///   halfWidths = positive half widths
///   transform = local transform of box
///   postScale = scale applied after the transform, may be negative
b3BoxHull b3MakeScaledBoxHull(b3Vec3 halfWidths, b3Transform transform, b3Vec3 postScale);

/// This takes a box with a transform and post scale and converts it into a box with the
/// post scale resolved with new half-widths and transform. This accepts non-uniform and
/// negative scale. This is approximate if there is shear.
/// Params:
///   halfWidths = [in/out] the box half widths
///   transform = [in/out] the box transform with rotation and translation
///   postScale = the post scale being applied to the box after the transform
///   minHalfWidth = the minimum half width after scale is applied
void b3ScaleBox(b3Vec3* halfWidths, b3Transform* transform, b3Vec3 postScale, float minHalfWidth);

// ---------------------------------------------------------------------------
// Triangle mesh
// ---------------------------------------------------------------------------

/// Create a grid mesh along the x and z axes.
/// Params:
///   xCount = the number of rows in the x direction
///   zCount = the number of rows in the z direction
///   cellWidth = the width of each cell
///   materialCount = the number of materials to generate
///   identifyEdges = compute adjacency information
b3MeshData* b3CreateGridMesh(int xCount, int zCount, float cellWidth, int materialCount, bool identifyEdges);

/// Create a wave mesh along the x and z axes.
b3MeshData* b3CreateWaveMesh(int xCount, int zCount, float cellWidth, float amplitude, float rowFrequency, float columnFrequency);

/// Create a torus mesh.
b3MeshData* b3CreateTorusMesh(int radialResolution, int tubularResolution, float radius, float thickness);

/// Create a box mesh.
b3MeshData* b3CreateBoxMesh(b3Vec3 center, b3Vec3 extent, bool identifyEdges);

/// Create a hollow box mesh.
b3MeshData* b3CreateHollowBoxMesh(b3Vec3 center, b3Vec3 extent);

/// Create a platform mesh. A truncated pyramid.
b3MeshData* b3CreatePlatformMesh(b3Vec3 center, float height, float topWidth, float bottomWidth);

/// Create a generic mesh.
b3MeshData* b3CreateMesh(const(b3MeshDef)* def, int* degenerateTriangleIndices, int degenerateCapacity);

/// Destroy a mesh.
void b3DestroyMesh(b3MeshData* mesh);

/// Get the height of the mesh BVH.
int b3GetHeight(const(b3MeshData)* mesh);

// ---------------------------------------------------------------------------
// Height field
// ---------------------------------------------------------------------------

/// Create a generic height field.
b3HeightFieldData* b3CreateHeightField(const(b3HeightFieldDef)* data);

/// Create a grid as a height field.
b3HeightFieldData* b3CreateGrid(int rowCount, int columnCount, b3Vec3 scale, bool makeHoles);

/// Create a wave grid as a height field.
b3HeightFieldData* b3CreateWave(int rowCount, int columnCount, b3Vec3 scale, float rowFrequency,
        float columnFrequency, bool makeHoles);

/// Destroy a height field.
void b3DestroyHeightField(b3HeightFieldData* heightField);

/// Save input height data to a file.
void b3DumpHeightData(const(b3HeightFieldDef)* data, const(char)* fileName);

/// Create a height field by loading a previously saved height data.
b3HeightFieldData* b3LoadHeightField(const(char)* fileName);

// ---------------------------------------------------------------------------
// Compound shape
// ---------------------------------------------------------------------------

/// Get a child shape of a compound.
b3ChildShape b3GetCompoundChild(const(b3CompoundData)* compound, int childIndex);

/// Query a compound shape for children that overlap an AABB.
void b3QueryCompound(const(b3CompoundData)* compound, b3AABB aabb, b3CompoundQueryFcn fcn, void* context);

/// Access a child capsule by index.
b3CompoundCapsule b3GetCompoundCapsule(const(b3CompoundData)* compound, int index);

/// Access a child hull by index.
b3CompoundHull b3GetCompoundHull(const(b3CompoundData)* compound, int index);

/// Access a child mesh by index.
b3CompoundMesh b3GetCompoundMesh(const(b3CompoundData)* compound, int index);

/// Access a child sphere by index.
b3CompoundSphere b3GetCompoundSphere(const(b3CompoundData)* compound, int index);

/// Access the compound material array.
const(b3SurfaceMaterial)* b3GetCompoundMaterials(const(b3CompoundData)* compound);

/// Create a compound shape. All input data in the definition is cloned into the resulting compound.
b3CompoundData* b3CreateCompound(const(b3CompoundDef)* def);

/// Destroy a compound shape.
void b3DestroyCompound(b3CompoundData* compound);

/// Clone all the compound data into a bytes buffer. This is expected to run offline or
/// asynchronously. This mutates the compound to nullify pointers, leaving the compound
/// in an unusable state.
ubyte* b3ConvertCompoundToBytes(b3CompoundData* compound);

/// Convert bytes to compound. This does not clone. The bytes must remain in scope while
/// the compound is used. This is done to improve run-time performance and allow for
/// instancing. The bytes are mutated to fixup pointers.
b3CompoundData* b3ConvertBytesToCompound(ubyte* bytes, int byteCount);

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// Compute mass properties of a sphere.
b3MassData b3ComputeSphereMass(const(b3Sphere)* shape, float density);

/// Compute mass properties of a capsule.
b3MassData b3ComputeCapsuleMass(const(b3Capsule)* shape, float density);

/// Compute mass properties of a hull.
b3MassData b3ComputeHullMass(const(b3HullData)* shape, float density);

/// Compute the bounding box of a transformed sphere.
b3AABB b3ComputeSphereAABB(const(b3Sphere)* shape, b3Transform transform);

/// Compute the bounding box of a transformed capsule.
b3AABB b3ComputeCapsuleAABB(const(b3Capsule)* shape, b3Transform transform);

/// Compute the bounding box of a transformed hull.
b3AABB b3ComputeHullAABB(const(b3HullData)* shape, b3Transform transform);

/// Compute the bounding box of a transformed mesh. Scale may be non-uniform and have negative components.
b3AABB b3ComputeMeshAABB(const(b3MeshData)* shape, b3Transform transform, b3Vec3 scale);

/// Compute the bounding box of a transformed height-field.
b3AABB b3ComputeHeightFieldAABB(const(b3HeightFieldData)* shape, b3Transform transform);

/// Compute the bounding box of a compound.
b3AABB b3ComputeCompoundAABB(const(b3CompoundData)* shape, b3Transform transform);

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

/// Use this to ensure your ray cast input is valid and avoid internal assertions.
bool b3IsValidRay(const(b3RayCastInput)* input);

/// Overlap shape versus capsule.
bool b3OverlapCapsule(const(b3Capsule)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Overlap shape versus compound.
bool b3OverlapCompound(const(b3CompoundData)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Overlap shape versus height field.
bool b3OverlapHeightField(const(b3HeightFieldData)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Overlap shape versus hull.
bool b3OverlapHull(const(b3HullData)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Overlap shape versus mesh.
bool b3OverlapMesh(const(b3Mesh)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Overlap shape versus sphere.
bool b3OverlapSphere(const(b3Sphere)* shape, b3Transform shapeTransform, const(b3ShapeProxy)* proxy);

/// Ray cast versus sphere in local space. A zero length ray is a point query. Initial
/// overlap reports a hit at the ray origin with zero fraction and zero normal.
b3CastOutput b3RayCastSphere(const(b3Sphere)* shape, const(b3RayCastInput)* input);

/// Ray cast versus a hollow sphere shell in local space. Unlike the solid sphere a ray
/// starting inside is not an overlap: it passes through and hits the far wall.
b3CastOutput b3RayCastHollowSphere(const(b3Sphere)* shape, const(b3RayCastInput)* input);

/// Ray cast versus capsule in local space. A zero length ray is a point query. Initial
/// overlap reports a hit at the ray origin with zero fraction and zero normal.
b3CastOutput b3RayCastCapsule(const(b3Capsule)* shape, const(b3RayCastInput)* input);

/// Ray cast versus compound in local space. A zero length ray is a point query. Initial
/// overlap with a child reports a hit at the ray origin with zero fraction and zero normal.
b3CastOutput b3RayCastCompound(const(b3CompoundData)* shape, const(b3RayCastInput)* input);

/// Ray cast versus hull shape in local space. A zero length ray is a point query. Initial
/// overlap reports a hit at the ray origin with zero fraction and zero normal.
b3CastOutput b3RayCastHull(const(b3HullData)* shape, const(b3RayCastInput)* input);

/// Ray cast versus mesh in local space. A thin surface with no interior, so there is no overlap case.
b3CastOutput b3RayCastMesh(const(b3Mesh)* shape, const(b3RayCastInput)* input);

/// Ray cast versus height field in local space. A thin surface with no interior, so there is no overlap case.
b3CastOutput b3RayCastHeightField(const(b3HeightFieldData)* shape, const(b3RayCastInput)* input);

/// Shape cast versus a sphere. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastSphere(const(b3Sphere)* shape, const(b3ShapeCastInput)* input);

/// Shape cast versus a capsule. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastCapsule(const(b3Capsule)* shape, const(b3ShapeCastInput)* input);

/// Shape cast versus compound. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastCompound(const(b3CompoundData)* shape, const(b3ShapeCastInput)* input);

/// Shape cast versus a hull. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastHull(const(b3HullData)* shape, const(b3ShapeCastInput)* input);

/// Shape cast versus a mesh. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastMesh(const(b3Mesh)* shape, const(b3ShapeCastInput)* input);

/// Shape cast versus a height field. Initial overlap is treated as a miss.
b3CastOutput b3ShapeCastHeightField(const(b3HeightFieldData)* shape, const(b3ShapeCastInput)* input);

/// Query callback. Return true to continue the query.
alias b3MeshQueryFcn = bool function(b3Vec3 a, b3Vec3 b, b3Vec3 c, int triangleIndex, void* context);

/// Query a mesh for triangles overlapping a bounding box in local space. May have false
/// positives. Useful for debug draw.
/// Params:
///   mesh = the mesh to query, includes scale
///   bounds = the bounding box in local space
///   fcn = a user function to collect triangles
///   context = the context sent to the user function
void b3QueryMesh(const(b3Mesh)* mesh, const b3AABB bounds, b3MeshQueryFcn fcn, void* context);

/// Query a height field for triangles overlapping a bounding box in local space. May have
/// false positives. Useful for debug draw.
/// Params:
///   heightField = the height field to query
///   bounds = the bounding box in local space
///   fcn = a user function to collect triangles
///   context = the context sent to the user function
void b3QueryHeightField(const(b3HeightFieldData)* heightField, b3AABB bounds, b3MeshQueryFcn fcn, void* context);

/// Compute the closest points between two shapes represented as point clouds.
/// `b3SimplexCache` cache is input/output. On the first call set `b3SimplexCache.count` to zero.
/// The query runs in frame A, so the witness points and normal are returned in frame A.
/// The underlying GJK algorithm may be debugged by passing in debug simplexes and capacity.
/// You may pass in null and 0 for these.
b3DistanceOutput b3ShapeDistance(const(b3DistanceInput)* input, b3SimplexCache* cache, b3Simplex* simplexes, int simplexCapacity);

/// Perform a linear shape cast of shape B moving and shape A fixed. Determines the hit
/// point, normal, and translation fraction. The query runs in frame A, so the hit point
/// and normal are returned in frame A. Initially touching shapes are a miss.
b3CastOutput b3ShapeCast(const(b3ShapeCastPairInput)* input);

/// Evaluate the transform sweep at a specific time.
b3Transform b3GetSweepTransform(const(b3Sweep)* sweep, float time);

/// Compute the upper bound on time before two shapes penetrate. Time is represented as
/// a fraction between [0,tMax]. This uses a swept separating axis and may miss some
/// intermediate, non-tunneling collisions. If you change the time interval, you should
/// call this function again.
b3TOIOutput b3TimeOfImpact(const(b3TOIInput)* input);

// ---------------------------------------------------------------------------
// Collision manifolds
// ---------------------------------------------------------------------------

/// Collide two spheres.
void b3CollideSpheres(b3LocalManifold* manifold, int capacity, const(b3Sphere)* sphereA,
        const(b3Sphere)* sphereB, b3Transform transformBtoA);

/// Collide a capsule and a sphere.
void b3CollideCapsuleAndSphere(b3LocalManifold* manifold, int capacity, const(b3Capsule)* capsuleA,
        const(b3Sphere)* sphereB, b3Transform transformBtoA);

/// Collide a hull and a sphere.
void b3CollideHullAndSphere(b3LocalManifold* manifold, int capacity, const(b3HullData)* hullA,
        const(b3Sphere)* sphereB, b3Transform transformBtoA, b3SimplexCache* cache);

/// Collide two capsules.
void b3CollideCapsules(b3LocalManifold* manifold, int capacity, const(b3Capsule)* capsuleA,
        const(b3Capsule)* capsuleB, b3Transform transformBtoA);

/// Collide a hull and a capsule.
void b3CollideHullAndCapsule(b3LocalManifold* manifold, int capacity, const(b3HullData)* hullA,
        const(b3Capsule)* capsuleB, b3Transform transformBtoA, b3SimplexCache* cache);

/// Collide two hulls.
void b3CollideHulls(b3LocalManifold* manifold, int capacity, const(b3HullData)* hullA,
        const(b3HullData)* hullB, b3Transform transformBtoA, b3SATCache* cache);

/// Collide a capsule and a triangle.
void b3CollideCapsuleAndTriangle(b3LocalManifold* manifold, int capacity, const(b3Capsule)* capsuleA,
        const(b3Vec3)* triangleB, b3SimplexCache* cache);

/// Collide a hull and a triangle.
void b3CollideHullAndTriangle(b3LocalManifold* manifold, int capacity, const(b3HullData)* hullA, b3Vec3 v1,
        b3Vec3 v2, b3Vec3 v3, int triangleFlags, b3SATCache* cache);

/// Collide a sphere and a triangle.
void b3CollideSphereAndTriangle(b3LocalManifold* manifold, int capacity, const(b3Sphere)* sphereA, const(b3Vec3)* triangleB);

// ---------------------------------------------------------------------------
// Character mover
// ---------------------------------------------------------------------------

/// Solves the position of a mover that satisfies the given collision planes.
/// Params:
///   targetDelta = the desired translation from the position used to generate the collision planes
///   planes = the collision planes
///   count = the number of collision planes
b3PlaneSolverResult b3SolvePlanes(b3Vec3 targetDelta, b3CollisionPlane* planes, int count);

/// Clips the velocity against the given collision planes. Planes with zero push or
/// clipVelocity set to false are skipped.
b3Vec3 b3ClipVector(b3Vec3 vector, const(b3CollisionPlane)* planes, int count);

extern (D):

// ---------------------------------------------------------------------------
// Inline helpers (B3_INLINE in the C header, reimplemented in D)
// ---------------------------------------------------------------------------

/// Get proxy user data.
pragma(inline, true) ulong b3DynamicTree_GetUserData(const(b3DynamicTree)* tree, int proxyId)
{
    return tree.nodes[proxyId].userData;
}

/// Get the AABB of a proxy.
pragma(inline, true) b3AABB b3DynamicTree_GetAABB(const(b3DynamicTree)* tree, int proxyId)
{
    return tree.nodes[proxyId].aabb;
}

/// Get read only hull vertices.
pragma(inline, true) const(b3HullVertex)* b3GetHullVertices(const(b3HullData)* hull)
{
    if (hull.vertexOffset == 0)
        return null;
    return cast(const(b3HullVertex)*)(cast(const(ubyte)*) hull + hull.vertexOffset);
}

/// Get read only hull points.
pragma(inline, true) const(b3Vec3)* b3GetHullPoints(const(b3HullData)* hull)
{
    if (hull.pointOffset == 0)
        return null;
    return cast(const(b3Vec3)*)(cast(const(ubyte)*) hull + hull.pointOffset);
}

/// Get read only hull half edges.
pragma(inline, true) const(b3HullHalfEdge)* b3GetHullEdges(const(b3HullData)* hull)
{
    if (hull.edgeOffset == 0)
        return null;
    return cast(const(b3HullHalfEdge)*)(cast(const(ubyte)*) hull + hull.edgeOffset);
}

/// Get read only hull faces.
pragma(inline, true) const(b3HullFace)* b3GetHullFaces(const(b3HullData)* hull)
{
    if (hull.faceOffset == 0)
        return null;
    return cast(const(b3HullFace)*)(cast(const(ubyte)*) hull + hull.faceOffset);
}

/// Get read only hull planes.
pragma(inline, true) const(b3Plane)* b3GetHullPlanes(const(b3HullData)* hull)
{
    if (hull.planeOffset == 0)
        return null;
    return cast(const(b3Plane)*)(cast(const(ubyte)*) hull + hull.planeOffset);
}

/// Get read only mesh BVH nodes.
pragma(inline, true) const(b3MeshNode)* b3GetMeshNodes(const(b3MeshData)* mesh)
{
    if (mesh.nodeOffset == 0)
        return null;
    return cast(const(b3MeshNode)*)(cast(const(ubyte)*) mesh + mesh.nodeOffset);
}

/// Get read only mesh vertices.
pragma(inline, true) const(b3Vec3)* b3GetMeshVertices(const(b3MeshData)* mesh)
{
    if (mesh.vertexOffset == 0)
        return null;
    return cast(const(b3Vec3)*)(cast(const(ubyte)*) mesh + mesh.vertexOffset);
}

/// Get read only mesh triangles.
pragma(inline, true) const(b3MeshTriangle)* b3GetMeshTriangles(const(b3MeshData)* mesh)
{
    if (mesh.triangleOffset == 0)
        return null;
    return cast(const(b3MeshTriangle)*)(cast(const(ubyte)*) mesh + mesh.triangleOffset);
}

/// Get read only mesh materials. The count is equal to the triangle count.
pragma(inline, true) const(ubyte)* b3GetMeshMaterialIndices(const(b3MeshData)* mesh)
{
    if (mesh.materialOffset == 0)
        return null;
    return cast(const(ubyte)*) mesh + mesh.materialOffset;
}

/// Get read only mesh flags. The count is equal to the triangle count.
pragma(inline, true) const(ubyte)* b3GetMeshFlags(const(b3MeshData)* mesh)
{
    if (mesh.flagsOffset == 0)
        return null;
    return cast(const(ubyte)*) mesh + mesh.flagsOffset;
}

/// Get read only compressed heights. One `ushort` per grid point.
pragma(inline, true) const(ushort)* b3GetHeightFieldCompressedHeights(const(b3HeightFieldData)* hf)
{
    if (hf.heightsOffset == 0)
        return null;
    return cast(const(ushort)*)(cast(const(ubyte)*) hf + hf.heightsOffset);
}

/// Get read only material indices. One `ubyte` per cell.
pragma(inline, true) const(ubyte)* b3GetHeightFieldMaterialIndices(const(b3HeightFieldData)* hf)
{
    if (hf.materialOffset == 0)
        return null;
    return cast(const(ubyte)*) hf + hf.materialOffset;
}

/// Get read only triangle flags. One `ubyte` per triangle.
pragma(inline, true) const(ubyte)* b3GetHeightFieldFlags(const(b3HeightFieldData)* hf)
{
    if (hf.flagsOffset == 0)
        return null;
    return cast(const(ubyte)*) hf + hf.flagsOffset;
}
