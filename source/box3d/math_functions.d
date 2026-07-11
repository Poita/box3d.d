// SPDX-License-Identifier: MIT
/++
    Vector math types and functions.

    Translated from `box3d/math_functions.h`. The header-only inline helpers are
    reimplemented in D; the remaining `B3_API` functions are `extern(C)` bindings
    into the library.

    This binds the default single-precision build of Box3D, so `b3Pos` aliases
    `b3Vec3` and `b3WorldTransform` aliases `b3Transform`.
+/
module box3d.math_functions;

import core.stdc.math : sqrtf, remainderf;

@safe nothrow @nogc:

/// https://en.wikipedia.org/wiki/Pi
enum float B3_PI = 3.14159265359f;

/// Convenience constant to convert from degrees to radians.
enum float B3_DEG_TO_RAD = 0.01745329251f;

/// Convenience constant to convert from radians to degrees.
enum float B3_RAD_TO_DEG = 57.2957795131f;

/// Minimum scale used for scaling collision meshes, etc.
enum float B3_MIN_SCALE = 0.01f;

/// A 2D vector.
struct b3Vec2
{
    float x = 0; /// coordinates
    float y = 0; /// ditto
}

/// A 3D vector.
struct b3Vec3
{
    float x = 0; /// coordinates
    float y = 0; /// ditto
    float z = 0; /// ditto

    /// Vector negation.
    b3Vec3 opUnary(string op : "-")() const pure => b3Vec3(-x, -y, -z);

    /// Vector addition and subtraction.
    b3Vec3 opBinary(string op)(b3Vec3 rhs) const pure if (op == "+" || op == "-")
    {
        return mixin("b3Vec3(x " ~ op ~ " rhs.x, y " ~ op ~ " rhs.y, z " ~ op ~ " rhs.z)");
    }

    /// Scalar multiplication (`v * s` and `s * v`).
    b3Vec3 opBinary(string op : "*")(float s) const pure => b3Vec3(x * s, y * s, z * s);
    b3Vec3 opBinaryRight(string op : "*")(float s) const pure => b3Vec3(s * x, s * y, s * z); /// ditto

    /// Compound assignment.
    ref b3Vec3 opOpAssign(string op)(b3Vec3 rhs) pure if (op == "+" || op == "-")
    {
        mixin("x " ~ op ~ "= rhs.x; y " ~ op ~ "= rhs.y; z " ~ op ~ "= rhs.z;");
        return this;
    }

    /// ditto
    ref b3Vec3 opOpAssign(string op : "*")(float s) pure
    {
        x *= s;
        y *= s;
        z *= s;
        return this;
    }
}

/// Cosine and sine pair. Uses a custom implementation for cross-platform determinism.
struct b3CosSin
{
    float cosine = 0; /// cosine
    float sine = 0; /// sine
}

/// A quaternion.
struct b3Quat
{
    b3Vec3 v; /// vector part
    float s = 1; /// scalar part
}

/// A rigid transform.
struct b3Transform
{
    b3Vec3 p;
    b3Quat q;
}

/// A world position. Single precision in the default build.
alias b3Pos = b3Vec3;

/// A world transform. Single precision in the default build.
alias b3WorldTransform = b3Transform;

/// A 3-by-3 matrix, stored in column-major order.
struct b3Matrix3
{
    b3Vec3 cx; /// columns
    b3Vec3 cy; /// ditto
    b3Vec3 cz; /// ditto
}

/// Axis-aligned bounding box.
struct b3AABB
{
    b3Vec3 lowerBound;
    b3Vec3 upperBound;
}

/// A plane: `separation = dot(normal, point) - offset`.
struct b3Plane
{
    b3Vec3 normal;
    float offset = 0;
}

/// The closest points between two segments or infinite lines.
struct b3SegmentDistanceResult
{
    b3Vec3 point1;
    float fraction1 = 0;
    b3Vec3 point2;
    float fraction2 = 0;
}

/// Zero vector.
enum b3Vec3 b3Vec3_zero = b3Vec3(0.0f, 0.0f, 0.0f);

/// One vector.
enum b3Vec3 b3Vec3_one = b3Vec3(1.0f, 1.0f, 1.0f);

/// Unit x-axis.
enum b3Vec3 b3Vec3_axisX = b3Vec3(1.0f, 0.0f, 0.0f);

/// Unit y-axis.
enum b3Vec3 b3Vec3_axisY = b3Vec3(0.0f, 1.0f, 0.0f);

/// Unit z-axis.
enum b3Vec3 b3Vec3_axisZ = b3Vec3(0.0f, 0.0f, 1.0f);

/// Identity quaternion.
enum b3Quat b3Quat_identity = b3Quat(b3Vec3(0.0f, 0.0f, 0.0f), 1.0f);

/// Identity transform.
enum b3Transform b3Transform_identity = b3Transform(b3Vec3(0.0f, 0.0f, 0.0f), b3Quat(b3Vec3(0.0f, 0.0f, 0.0f), 1.0f));

/// Zero matrix.
enum b3Matrix3 b3Mat3_zero = b3Matrix3(b3Vec3(0.0f, 0.0f, 0.0f), b3Vec3(0.0f, 0.0f, 0.0f), b3Vec3(0.0f, 0.0f, 0.0f));

/// Identity matrix.
enum b3Matrix3 b3Mat3_identity = b3Matrix3(b3Vec3(1.0f, 0.0f, 0.0f), b3Vec3(0.0f, 1.0f, 0.0f), b3Vec3(0.0f, 0.0f, 1.0f));

/// Zero world position.
enum b3Pos b3Pos_zero = b3Pos(0.0f, 0.0f, 0.0f);

/// Identity world transform.
enum b3WorldTransform b3WorldTransform_identity = b3WorldTransform(b3Vec3(0.0f, 0.0f, 0.0f),
            b3Quat(b3Vec3(0.0f, 0.0f, 0.0f), 1.0f));

extern (C):

/// Is this a valid number? Not NaN or infinity.
bool b3IsValidFloat(float a);

/// Compute an approximate arctangent in the range [-pi, pi].
/// Hand coded for cross-platform determinism. Accurate to around 0.0023 degrees.
float b3Atan2(float y, float x);

/// Compute the cosine and sine of an angle in radians (cross-platform deterministic).
b3CosSin b3ComputeCosSin(float radians);

/// Extract a quaternion from a rotation matrix.
b3Quat b3MakeQuatFromMatrix(scope const(b3Matrix3)* m) @system;

/// Find a quaternion that rotates one vector to another.
b3Quat b3ComputeQuatBetweenUnitVectors(b3Vec3 v1, b3Vec3 v2);

/// Get the inertia tensor of an offset point.
/// https://en.wikipedia.org/wiki/Parallel_axis_theorem
b3Matrix3 b3Steiner(float mass, b3Vec3 origin);

/// Compute the closest point on the segment a-b to the target q.
b3Vec3 b3PointToSegmentDistance(b3Vec3 a, b3Vec3 b, b3Vec3 q);

/// Compute the closest points on two infinite lines.
b3SegmentDistanceResult b3LineDistance(b3Vec3 p1, b3Vec3 d1, b3Vec3 p2, b3Vec3 d2);

/// Compute the closest points on two line segments.
b3SegmentDistanceResult b3SegmentDistance(b3Vec3 p1, b3Vec3 q1, b3Vec3 p2, b3Vec3 q2);

/// Is this a valid vector? Not NaN or infinity.
bool b3IsValidVec3(b3Vec3 a);

/// Is this a valid quaternion? Not NaN or infinity. Is normalized.
bool b3IsValidQuat(b3Quat q);

/// Is this a valid transform? Not NaN or infinity. Is normalized.
bool b3IsValidTransform(b3Transform a);

/// Is this a valid matrix? Not NaN or infinity.
bool b3IsValidMatrix3(b3Matrix3 a);

/// Is this a valid bounding box? Not NaN or infinity. Upper bound greater than or equal to lower bound.
bool b3IsValidAABB(b3AABB a);

/// Is this AABB reasonably close to the origin? See B3_HUGE.
bool b3IsBoundedAABB(b3AABB a);

/// Is this AABB valid and reasonable?
bool b3IsSaneAABB(b3AABB a);

/// Is this a valid plane? Normal is a unit vector. Not NaN or infinity.
bool b3IsValidPlane(b3Plane a);

/// Is this a valid world position? Not NaN or infinity.
bool b3IsValidPosition(b3Pos p);

/// Is this a valid world transform? Not NaN or infinity. Rotation is normalized.
bool b3IsValidWorldTransform(b3WorldTransform t);

extern (D):

@safe:

/// Returns: the minimum of two integers.
pragma(inline, true) int b3MinInt(int a, int b) => a < b ? a : b;

/// Returns: the maximum of two integers.
pragma(inline, true) int b3MaxInt(int a, int b) => a > b ? a : b;

/// Returns: an integer clamped between a lower and upper bound.
pragma(inline, true) int b3ClampInt(int a, int lower, int upper) => a < lower ? lower : (upper < a ? upper : a);

/// Returns: the absolute value of a float.
pragma(inline, true) float b3AbsFloat(float a) => a < 0 ? -a : a;

/// Returns: the minimum of two floats.
pragma(inline, true) float b3MinFloat(float a, float b) => a < b ? a : b;

/// Returns: the maximum of two floats.
pragma(inline, true) float b3MaxFloat(float a, float b) => a > b ? a : b;

/// Returns: a float clamped between a lower and upper bound.
pragma(inline, true) float b3ClampFloat(float a, float lower, float upper) => a < lower ? lower : (upper < a ? upper : a);

/// Interpolate a scalar.
pragma(inline, true) float b3LerpFloat(float a, float b, float alpha) => (1.0f - alpha) * a + alpha * b;

/// Deprecated: use `b3ComputeCosSin`.
deprecated("Use b3ComputeCosSin") pragma(inline, true) float b3Sin(float radians)
{
    immutable b3CosSin cs = b3ComputeCosSin(radians);
    return cs.sine;
}

/// Deprecated: use `b3ComputeCosSin`.
deprecated("Use b3ComputeCosSin") pragma(inline, true) float b3Cos(float radians)
{
    immutable b3CosSin cs = b3ComputeCosSin(radians);
    return cs.cosine;
}

/// Convert any angle into the range [-pi, pi].
pragma(inline, true) float b3UnwindAngle(float radians) => remainderf(radians, 2.0f * B3_PI);

/// Vector addition.
pragma(inline, true) b3Vec3 b3Add(b3Vec3 a, b3Vec3 b) => b3Vec3(a.x + b.x, a.y + b.y, a.z + b.z);

/// Vector subtraction.
pragma(inline, true) b3Vec3 b3Sub(b3Vec3 a, b3Vec3 b) => b3Vec3(a.x - b.x, a.y - b.y, a.z - b.z);

/// Vector component-wise multiplication.
pragma(inline, true) b3Vec3 b3Mul(b3Vec3 a, b3Vec3 b) => b3Vec3(a.x * b.x, a.y * b.y, a.z * b.z);

/// Vector negation.
pragma(inline, true) b3Vec3 b3Neg(b3Vec3 a) => b3Vec3(-a.x, -a.y, -a.z);

/// Vector dot product.
pragma(inline, true) float b3Dot(b3Vec3 a, b3Vec3 b) => a.x * b.x + a.y * b.y + a.z * b.z;

/// Vector length.
pragma(inline, true) float b3Length(b3Vec3 v) => sqrtf(b3Dot(v, v));

/// Vector length squared.
pragma(inline, true) float b3LengthSquared(b3Vec3 a) => a.x * a.x + a.y * a.y + a.z * a.z;

/// Distance between two points.
pragma(inline, true) float b3Distance(b3Vec3 a, b3Vec3 b)
{
    immutable b3Vec3 dv = b3Vec3(b.x - a.x, b.y - a.y, b.z - a.z);
    return b3Length(dv);
}

/// Squared distance between two points.
pragma(inline, true) float b3DistanceSquared(b3Vec3 a, b3Vec3 b)
{
    immutable b3Vec3 dv = b3Vec3(b.x - a.x, b.y - a.y, b.z - a.z);
    return dv.x * dv.x + dv.y * dv.y + dv.z * dv.z;
}

/// Normalize a vector. Returns a zero vector if the input vector is very small.
b3Vec3 b3Normalize(b3Vec3 a)
{
    immutable float lengthSquared = a.x * a.x + a.y * a.y + a.z * a.z;

    if (lengthSquared > 1000.0f * float.min_normal)
    {
        immutable float s = 1.0f / sqrtf(lengthSquared);
        return b3Vec3(s * a.x, s * a.y, s * a.z);
    }

    return b3Vec3(0.0f, 0.0f, 0.0f);
}

/// Normalize a vector and return the length. Returns a zero vector
/// if the input is very small.
b3Vec3 b3GetLengthAndNormalize(scope float* length, b3Vec3 a) @system
{
    *length = b3Length(a);
    if (*length < float.epsilon)
        return b3Vec3_zero;

    immutable float invLength = 1.0f / *length;
    return b3Vec3(invLength * a.x, invLength * a.y, invLength * a.z);
}

/// Get a unit vector that is perpendicular to the supplied vector.
pragma(inline, true) b3Vec3 b3Perp(b3Vec3 a)
{
    // Suppose vector a has all equal components and is a unit vector: a = (s, s, s)
    // Then 3*s*s = 1, s = sqrt(1/3) = 0.57735. This means that at least one component
    // of a unit vector must be greater or equal to 0.57735.
    b3Vec3 p;
    if (a.x < -0.5f || 0.5f < a.x)
        p = b3Vec3(a.y, -a.x, 0.0f);
    else
        p = b3Vec3(0.0f, a.z, -a.y);

    return b3Normalize(p);
}

/// Is a vector normalized? In other words, does it have unit length?
pragma(inline, true) bool b3IsNormalized(b3Vec3 a)
{
    immutable float aa = b3Dot(a, a);
    return b3AbsFloat(1.0f - aa) < 100.0f * float.epsilon;
}

/// `a + s * b`.
pragma(inline, true) b3Vec3 b3MulAdd(b3Vec3 a, float s, b3Vec3 b) => b3Vec3(a.x + s * b.x, a.y + s * b.y, a.z + s * b.z);

/// `a - s * b`.
pragma(inline, true) b3Vec3 b3MulSub(b3Vec3 a, float s, b3Vec3 b) => b3Vec3(a.x - s * b.x, a.y - s * b.y, a.z - s * b.z);

/// `s * a`.
pragma(inline, true) b3Vec3 b3MulSV(float s, b3Vec3 a) => b3Vec3(s * a.x, s * a.y, s * a.z);

/// https://en.wikipedia.org/wiki/Cross_product
pragma(inline, true) b3Vec3 b3Cross(b3Vec3 a, b3Vec3 b) => b3Vec3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x);

/// Linearly interpolate between two vectors.
pragma(inline, true) b3Vec3 b3Lerp(b3Vec3 a, b3Vec3 b, float alpha)
{
    assert(0.0f <= alpha && alpha <= 1.0f);

    return b3Vec3((1.0f - alpha) * a.x + alpha * b.x, (1.0f - alpha) * a.y + alpha * b.y, (1.0f - alpha) * a.z + alpha * b
            .z);
}

/// Blend two vectors: `s * a + t * b`.
pragma(inline, true) b3Vec3 b3Blend2(float s, b3Vec3 a, float t, b3Vec3 b) => b3Vec3(s * a.x + t * b.x,
        s * a.y + t * b.y, s * a.z + t * b.z);

/// Component-wise absolute value.
pragma(inline, true) b3Vec3 b3Abs(b3Vec3 a) => b3Vec3(b3AbsFloat(a.x), b3AbsFloat(a.y), b3AbsFloat(a.z));

/// Component-wise -1 or 1 (1 if zero).
pragma(inline, true) b3Vec3 b3Sign(b3Vec3 a) => b3Vec3(a.x >= 0.0f ? 1.0f : -1.0f, a.y >= 0.0f ? 1.0f : -1.0f,
        a.z >= 0.0f ? 1.0f : -1.0f);

/// Component-wise minimum value.
pragma(inline, true) b3Vec3 b3Min(b3Vec3 a, b3Vec3 b) => b3Vec3(b3MinFloat(a.x, b.x), b3MinFloat(a.y, b.y),
        b3MinFloat(a.z, b.z));

/// Component-wise maximum value.
pragma(inline, true) b3Vec3 b3Max(b3Vec3 a, b3Vec3 b) => b3Vec3(b3MaxFloat(a.x, b.x), b3MaxFloat(a.y, b.y),
        b3MaxFloat(a.z, b.z));

/// Component-wise clamped value.
pragma(inline, true) b3Vec3 b3Clamp(b3Vec3 a, b3Vec3 lower, b3Vec3 upper) => b3Vec3(b3ClampFloat(a.x,
        lower.x, upper.x), b3ClampFloat(a.y, lower.y, upper.y), b3ClampFloat(a.z, lower.z, upper.z));

/// Create a safe scaling value for scaling collision. This allows
/// negative scale, but keeps scale sufficiently far from zero.
pragma(inline, true) b3Vec3 b3SafeScale(b3Vec3 a)
{
    immutable b3Vec3 absScale = b3Abs(a);
    immutable b3Vec3 minScale = b3Vec3(B3_MIN_SCALE, B3_MIN_SCALE, B3_MIN_SCALE);
    return b3Mul(b3Sign(a), b3Max(absScale, minScale));
}

/// Does the supplied quaternion have unit length?
pragma(inline, true) bool b3IsNormalizedQuat(b3Quat q)
{
    immutable float qq = q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z + q.s * q.s;
    return 1.0f - 20.0f * float.epsilon < qq && qq < 1.0f + 20.0f * float.epsilon;
}

/// Rotate a vector.
pragma(inline, true) b3Vec3 b3RotateVector(b3Quat q, b3Vec3 v)
{
    // v + 2 * cross(q.v, cross(q.v, v) + q.s * v)
    immutable b3Vec3 t1 = b3Cross(q.v, v);
    immutable b3Vec3 t2 = b3MulAdd(t1, q.s, v);
    immutable b3Vec3 t3 = b3Cross(q.v, t2);
    return b3MulAdd(v, 2.0f, t3);
}

/// Inverse rotate a vector.
pragma(inline, true) b3Vec3 b3InvRotateVector(b3Quat q, b3Vec3 v)
{
    // v + 2 * cross(q.v, cross(q.v, v) - q.s * v)
    immutable b3Vec3 t1 = b3Cross(q.v, v);
    immutable b3Vec3 t2 = b3MulSub(t1, q.s, v);
    immutable b3Vec3 t3 = b3Cross(q.v, t2);
    return b3MulAdd(v, 2.0f, t3);
}

/// Compute dot product of two quaternions. Useful for polarity tests.
pragma(inline, true) float b3DotQuat(b3Quat a, b3Quat b) => a.v.x * b.v.x + a.v.y * b.v.y + a.v.z * b.v.z + a.s * b.s;

/// Multiply two quaternions.
pragma(inline, true) b3Quat b3MulQuat(b3Quat q1, b3Quat q2)
{
    immutable b3Vec3 t1 = b3Cross(q1.v, q2.v);
    immutable b3Vec3 t2 = b3MulAdd(t1, q1.s, q2.v);
    immutable b3Vec3 t3 = b3MulAdd(t2, q2.s, q1.v);
    return b3Quat(t3, q1.s * q2.s - b3Dot(q1.v, q2.v));
}

/// Compute a relative quaternion: `inv(q1) * q2`.
pragma(inline, true) b3Quat b3InvMulQuat(b3Quat q1, b3Quat q2)
{
    immutable b3Vec3 t1 = b3Cross(q2.v, q1.v);
    immutable b3Vec3 t2 = b3MulAdd(t1, q1.s, q2.v);
    immutable b3Vec3 t3 = b3MulSub(t2, q2.s, q1.v);
    return b3Quat(t3, q1.s * q2.s + b3Dot(q1.v, q2.v));
}

/// Quaternion conjugate (cheap inverse).
pragma(inline, true) b3Quat b3Conjugate(b3Quat q) => b3Quat(b3Vec3(-q.v.x, -q.v.y, -q.v.z), q.s);

/// Component-wise quaternion negation.
pragma(inline, true) b3Quat b3NegateQuat(b3Quat q) => b3Quat(b3Vec3(-q.v.x, -q.v.y, -q.v.z), -q.s);

/// Normalize a quaternion.
b3Quat b3NormalizeQuat(b3Quat q)
{
    immutable float lengthSq = b3DotQuat(q, q);
    if (lengthSq > 1000.0f * float.min_normal)
    {
        immutable float s = 1.0f / sqrtf(lengthSq);
        return b3Quat(b3Vec3(s * q.v.x, s * q.v.y, s * q.v.z), s * q.s);
    }

    return b3Quat_identity;
}

/// Make a quaternion that is equivalent to rotating around an axis by a specified angle.
pragma(inline, true) b3Quat b3MakeQuatFromAxisAngle(b3Vec3 axis, float radians)
{
    assert(b3IsNormalized(axis));
    immutable b3CosSin cs = b3ComputeCosSin(0.5f * radians);
    return b3Quat(b3Vec3(cs.sine * axis.x, cs.sine * axis.y, cs.sine * axis.z), cs.cosine);
}

/// Get the axis and angle from a quaternion. Assumes the quaternion is normalized.
b3Vec3 b3GetAxisAngle(scope float* radians, b3Quat q) @system
{
    immutable float length = sqrtf(q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z);
    *radians = 2.0f * b3Atan2(length, q.s);
    if (length > 0.0f)
    {
        immutable float invLength = 1.0f / length;
        return b3Vec3(invLength * q.v.x, invLength * q.v.y, invLength * q.v.z);
    }

    return b3Vec3_zero;
}

/// Get the angle for a quaternion in radians.
pragma(inline, true) float b3GetQuatAngle(b3Quat q)
{
    immutable float length = sqrtf(q.v.x * q.v.x + q.v.y * q.v.y + q.v.z * q.v.z);
    return 2.0f * b3Atan2(length, q.s);
}

/// Twist angle around the z-axis, used for twist limit and revolute angle limit.
pragma(inline, true) float b3GetTwistAngle(b3Quat q)
{
    // Account for polarity to keep the twist angle in range.
    // This is simpler than asking the user to check polarity or unwinding.
    float twist = q.s < 0.0f ? b3Atan2(-q.v.z, -q.s) : b3Atan2(q.v.z, q.s);
    twist *= 2.0f;
    assert(-B3_PI <= twist && twist <= B3_PI);
    return twist;
}

/// Swing angle used for cone limit.
pragma(inline, true) float b3GetSwingAngle(b3Quat q)
{
    // Polarity should not matter because all terms are squared.
    immutable float x = sqrtf(q.v.z * q.v.z + q.s * q.s);
    immutable float y = sqrtf(q.v.x * q.v.x + q.v.y * q.v.y);
    immutable float swing = 2.0f * b3Atan2(y, x);
    assert(0.0f <= swing && swing <= B3_PI);
    return swing;
}

/// Linearly interpolate and normalize between two quaternions.
b3Quat b3NLerp(b3Quat q1, b3Quat q2, float alpha)
{
    assert(0.0f <= alpha && alpha <= 1.0f);
    if (b3DotQuat(q1, q2) < 0.0f)
        q1 = b3Quat(b3Vec3(-q1.v.x, -q1.v.y, -q1.v.z), -q1.s);

    b3Quat q;
    q.v = b3Lerp(q1.v, q2.v, alpha);
    q.s = (1.0f - alpha) * q1.s + alpha * q2.s;

    return b3NormalizeQuat(q);
}

/// Multiply two transforms. If the result is applied to a point p local to frame B,
/// the transform would first convert p to a point local to frame A, then into a point
/// in the world frame. This is useful if frame B is a child of frame A.
pragma(inline, true) b3Transform b3MulTransforms(b3Transform a, b3Transform b) => b3Transform(
        b3Add(b3RotateVector(a.q, b.p), a.p), b3MulQuat(a.q, b.q));

/// Creates a transform that converts a local point in frame B to a local point in frame A.
/// This is useful for transforming points between the local spaces of two frames that are
/// in world space.
pragma(inline, true) b3Transform b3InvMulTransforms(b3Transform a, b3Transform b) => b3Transform(
        b3InvRotateVector(a.q, b3Sub(b.p, a.p)), b3InvMulQuat(a.q, b.q));

/// Get the inverse of a transform.
pragma(inline, true) b3Transform b3InvertTransform(b3Transform t) => b3Transform(b3InvRotateVector(t.q,
        b3Neg(t.p)), b3Conjugate(t.q));

/// Transform a point.
pragma(inline, true) b3Vec3 b3TransformPoint(b3Transform t, b3Vec3 v) => b3Add(b3RotateVector(t.q, v), t.p);

/// Inverse transform a point.
pragma(inline, true) b3Vec3 b3InvTransformPoint(b3Transform t, b3Vec3 v) => b3InvRotateVector(t.q, b3Sub(v, t.p));

// World position boundary. These cross between the double precision world space at the public
// boundary and the float interior. In the single precision build the type aliases collapse
// and the conversions are no-ops.

/// Convert a vector to a world position. No-op in single precision.
pragma(inline, true) b3Pos b3ToPos(b3Vec3 v) => b3Pos(v.x, v.y, v.z);

/// Lossy conversion of a world position to a float vector. No-op in single precision.
pragma(inline, true) b3Vec3 b3ToVec3(b3Pos p) => b3Vec3(p.x, p.y, p.z);

/// Narrow a world coordinate to float, rounding toward negative infinity.
/// Plain conversion in single precision.
pragma(inline, true) float b3RoundDownFloat(double x) => cast(float) x;

/// Narrow a world coordinate to float, rounding toward positive infinity.
/// Plain conversion in single precision.
pragma(inline, true) float b3RoundUpFloat(double x) => cast(float) x;

/// `a - b`, demoted to float. The primary precision boundary operation.
pragma(inline, true) b3Vec3 b3SubPos(b3Pos a, b3Pos b) => b3Vec3(a.x - b.x, a.y - b.y, a.z - b.z);

/// `p + d`.
pragma(inline, true) b3Pos b3OffsetPos(b3Pos p, b3Vec3 d) => b3Pos(p.x + d.x, p.y + d.y, p.z + d.z);

/// World position interpolation for sweeps and sampling.
pragma(inline, true) b3Pos b3LerpPosition(b3Pos a, b3Pos b, float t) => b3Pos((1.0f - t) * a.x + t * b.x,
        (1.0f - t) * a.y + t * b.y, (1.0f - t) * a.z + t * b.z);

/// Transform a local point to a world position.
pragma(inline, true) b3Pos b3TransformWorldPoint(b3WorldTransform t, b3Vec3 p)
{
    immutable b3Vec3 r = b3RotateVector(t.q, p);
    return b3Pos(t.p.x + r.x, t.p.y + r.y, t.p.z + r.z);
}

/// Transform a world position to a local point.
pragma(inline, true) b3Vec3 b3InvTransformWorldPoint(b3WorldTransform t, b3Pos p)
{
    immutable b3Vec3 d = b3Vec3(cast(float)(p.x - t.p.x), cast(float)(p.y - t.p.y), cast(float)(p.z - t.p.z));
    return b3InvRotateVector(t.q, d);
}

/// Relative transform of frame B in frame A. The narrow phase boundary.
pragma(inline, true) b3Transform b3InvMulWorldTransforms(b3WorldTransform A, b3WorldTransform B)
{
    b3Transform C;
    C.q = b3InvMulQuat(A.q, B.q);
    immutable b3Vec3 d = b3Vec3(cast(float)(B.p.x - A.p.x), cast(float)(B.p.y - A.p.y), cast(float)(B.p.z - A.p.z));
    C.p = b3InvRotateVector(A.q, d);
    return C;
}

/// Compose a world transform with a local transform.
pragma(inline, true) b3WorldTransform b3MulWorldTransforms(b3WorldTransform A, b3Transform B)
{
    b3WorldTransform C;
    C.q = b3MulQuat(A.q, B.q);
    immutable b3Vec3 r = b3RotateVector(A.q, B.p);
    C.p = b3Pos(A.p.x + r.x, A.p.y + r.y, A.p.z + r.z);
    return C;
}

/// Shift a world transform into the frame of a base position.
pragma(inline, true) b3Transform b3ToRelativeTransform(b3WorldTransform t, b3Pos base) => b3Transform(
        b3Vec3(cast(float)(t.p.x - base.x), cast(float)(t.p.y - base.y), cast(float)(t.p.z - base.z)), t.q);

/// Promote a float transform to a world transform. Lossless.
pragma(inline, true) b3WorldTransform b3MakeWorldTransform(b3Transform t) => b3WorldTransform(b3ToPos(t.p), t.q);

/// Translate a local AABB by a world origin, rounding outward so the float box always contains
/// the double box. In the single precision build the origin is float and the rounding is a no-op.
pragma(inline, true) b3AABB b3OffsetAABB(b3AABB localBox, b3Pos origin)
{
    b3AABB result;
    result.lowerBound.x = b3RoundDownFloat(origin.x + localBox.lowerBound.x);
    result.lowerBound.y = b3RoundDownFloat(origin.y + localBox.lowerBound.y);
    result.lowerBound.z = b3RoundDownFloat(origin.z + localBox.lowerBound.z);
    result.upperBound.x = b3RoundUpFloat(origin.x + localBox.upperBound.x);
    result.upperBound.y = b3RoundUpFloat(origin.y + localBox.upperBound.y);
    result.upperBound.z = b3RoundUpFloat(origin.z + localBox.upperBound.z);
    return result;
}

/// Compute the determinant of a 3-by-3 matrix.
pragma(inline, true) float b3Det(b3Matrix3 m) => b3Dot(m.cx, b3Cross(m.cy, m.cz));

/// Multiply a matrix times a column vector.
pragma(inline, true) b3Vec3 b3MulMV(b3Matrix3 m, b3Vec3 a) => b3Vec3(m.cx.x * a.x + m.cy.x * a.y + m.cz.x * a.z,
        m.cx.y * a.x + m.cy.y * a.y + m.cz.y * a.z, m.cx.z * a.x + m.cy.z * a.y + m.cz.z * a.z);

/// Negate a matrix.
pragma(inline, true) b3Matrix3 b3NegateMat3(b3Matrix3 a) => b3Matrix3(b3Vec3(-a.cx.x, -a.cx.y, -a.cx.z),
        b3Vec3(-a.cy.x, -a.cy.y, -a.cy.z), b3Vec3(-a.cz.x, -a.cz.y, -a.cz.z));

/// Matrix addition.
/// Returns: `a + b`
pragma(inline, true) b3Matrix3 b3AddMM(b3Matrix3 a, b3Matrix3 b) => b3Matrix3(b3Vec3(a.cx.x + b.cx.x,
        a.cx.y + b.cx.y, a.cx.z + b.cx.z), b3Vec3(a.cy.x + b.cy.x, a.cy.y + b.cy.y, a.cy.z + b.cy.z),
        b3Vec3(a.cz.x + b.cz.x, a.cz.y + b.cz.y, a.cz.z + b.cz.z));

/// Matrix subtraction.
/// Returns: `a - b`
pragma(inline, true) b3Matrix3 b3SubMM(b3Matrix3 a, b3Matrix3 b) => b3Matrix3(b3Vec3(a.cx.x - b.cx.x,
        a.cx.y - b.cx.y, a.cx.z - b.cx.z), b3Vec3(a.cy.x - b.cy.x, a.cy.y - b.cy.y, a.cy.z - b.cy.z),
        b3Vec3(a.cz.x - b.cz.x, a.cz.y - b.cz.y, a.cz.z - b.cz.z));

/// Multiply a matrix by a scalar, component-wise.
pragma(inline, true) b3Matrix3 b3MulSM(float s, b3Matrix3 a) => b3Matrix3(b3Vec3(s * a.cx.x, s * a.cx.y, s * a.cx.z),
        b3Vec3(s * a.cy.x, s * a.cy.y, s * a.cy.z), b3Vec3(s * a.cz.x, s * a.cz.y, s * a.cz.z));

/// Matrix multiplication.
/// Returns: `a * b`
pragma(inline, true) b3Matrix3 b3MulMM(b3Matrix3 a, b3Matrix3 b) => b3Matrix3(b3MulMV(a, b.cx), b3MulMV(a,
        b.cy), b3MulMV(a, b.cz));

/// Matrix transpose.
pragma(inline, true) b3Matrix3 b3Transpose(b3Matrix3 m) => b3Matrix3(b3Vec3(m.cx.x, m.cy.x, m.cz.x),
        b3Vec3(m.cx.y, m.cy.y, m.cz.y), b3Vec3(m.cx.z, m.cy.z, m.cz.z));

/// General matrix inverse.
b3Matrix3 b3InvertMatrix(b3Matrix3 m)
{
    immutable float det = b3Det(m);
    if (b3AbsFloat(det) > 1000.0f * float.min_normal)
    {
        immutable float invDet = 1.0f / det;
        b3Matrix3 result;
        result.cx = b3MulSV(invDet, b3Cross(m.cy, m.cz));
        result.cy = b3MulSV(invDet, b3Cross(m.cz, m.cx));
        result.cz = b3MulSV(invDet, b3Cross(m.cx, m.cy));

        return b3Transpose(result);
    }

    return b3Mat3_zero;
}

/// Solve a matrix equation.
/// Returns: `inv(m) * a`
b3Vec3 b3Solve3(b3Matrix3 m, b3Vec3 a)
{
    immutable float det = b3Det(m);
    if (b3AbsFloat(det) > 1000.0f * float.min_normal)
    {
        immutable float invDet = 1.0f / det;
        b3Matrix3 s;
        s.cx = b3Cross(m.cy, m.cz);
        s.cy = b3Cross(m.cz, m.cx);
        s.cz = b3Cross(m.cx, m.cy);

        return b3Vec3(invDet * b3Dot(s.cx, a), invDet * b3Dot(s.cy, a), invDet * b3Dot(s.cz, a));
    }

    return b3Vec3_zero;
}

/// Invert a matrix, returning the transpose of the inverse.
b3Matrix3 b3InvertT(b3Matrix3 m)
{
    immutable float det = b3Det(m);
    if (b3AbsFloat(det) > 1000.0f * float.min_normal)
    {
        immutable float invDet = 1.0f / det;
        b3Matrix3 result;
        result.cx = b3MulSV(invDet, b3Cross(m.cy, m.cz));
        result.cy = b3MulSV(invDet, b3Cross(m.cz, m.cx));
        result.cz = b3MulSV(invDet, b3Cross(m.cx, m.cy));
        return result;
    }

    return b3Mat3_zero;
}

/// Get the component-wise absolute value of a matrix.
pragma(inline, true) b3Matrix3 b3AbsMatrix3(b3Matrix3 m) => b3Matrix3(b3Abs(m.cx), b3Abs(m.cy), b3Abs(m.cz));

/// Make a matrix from a quaternion. This is useful if you need to
/// rotate many vectors.
pragma(inline, true) b3Matrix3 b3MakeMatrixFromQuat(b3Quat q)
{
    immutable float xx = q.v.x * q.v.x;
    immutable float yy = q.v.y * q.v.y;
    immutable float zz = q.v.z * q.v.z;
    immutable float xy = q.v.x * q.v.y;
    immutable float xz = q.v.x * q.v.z;
    immutable float xw = q.v.x * q.s;
    immutable float yz = q.v.y * q.v.z;
    immutable float yw = q.v.y * q.s;
    immutable float zw = q.v.z * q.s;

    return b3Matrix3(b3Vec3(1.0f - 2.0f * (yy + zz), 2.0f * (xy + zw), 2.0f * (xz - yw)),
            b3Vec3(2.0f * (xy - zw), 1.0f - 2.0f * (xx + zz), 2.0f * (yz + xw)), b3Vec3(2.0f * (xz + yw),
                2.0f * (yz - xw), 1.0f - 2.0f * (xx + yy)));
}

/// Get the AABB of a point cloud.
b3AABB b3MakeAABB(scope const b3Vec3* points, int count, float radius) @system
{
    assert(count > 0);
    b3AABB a = b3AABB(points[0], points[0]);
    foreach (i; 1 .. count)
    {
        a.lowerBound = b3Min(a.lowerBound, points[i]);
        a.upperBound = b3Max(a.upperBound, points[i]);
    }

    immutable b3Vec3 r = b3Vec3(radius, radius, radius);
    a.lowerBound = b3Sub(a.lowerBound, r);
    a.upperBound = b3Add(a.upperBound, r);

    return a;
}

/// Does `a` fully contain `b`?
pragma(inline, true) bool b3AABB_Contains(b3AABB a, b3AABB b)
{
    if (a.lowerBound.x > b.lowerBound.x || b.upperBound.x > a.upperBound.x)
        return false;
    if (a.lowerBound.y > b.lowerBound.y || b.upperBound.y > a.upperBound.y)
        return false;
    if (a.lowerBound.z > b.lowerBound.z || b.upperBound.z > a.upperBound.z)
        return false;

    return true;
}

/// Get the surface area of an axis-aligned bounding box.
pragma(inline, true) float b3AABB_Area(b3AABB a)
{
    immutable b3Vec3 delta = b3Sub(a.upperBound, a.lowerBound);
    return 2.0f * (delta.x * delta.y + delta.y * delta.z + delta.z * delta.x);
}

/// Get the center of an axis-aligned bounding box.
pragma(inline, true) b3Vec3 b3AABB_Center(b3AABB a) => b3MulSV(0.5f, b3Add(a.upperBound, a.lowerBound));

/// Get the extents (half-widths) of an axis-aligned bounding box.
pragma(inline, true) b3Vec3 b3AABB_Extents(b3AABB a) => b3MulSV(0.5f, b3Sub(a.upperBound, a.lowerBound));

/// Get the union of two axis-aligned bounding boxes.
pragma(inline, true) b3AABB b3AABB_Union(b3AABB a, b3AABB b) => b3AABB(b3Min(a.lowerBound, b.lowerBound),
        b3Max(a.upperBound, b.upperBound));

/// Add uniform padding to an axis-aligned bounding box.
pragma(inline, true) b3AABB b3AABB_Inflate(b3AABB a, float extension)
{
    immutable b3Vec3 radius = b3Vec3(extension, extension, extension);
    return b3AABB(b3Sub(a.lowerBound, radius), b3Add(a.upperBound, radius));
}

/// Do two axis-aligned boxes overlap?
pragma(inline, true) bool b3AABB_Overlaps(b3AABB a, b3AABB b)
{
    // No intersection if separated along one axis
    if (a.upperBound.x < b.lowerBound.x || a.lowerBound.x > b.upperBound.x)
        return false;
    if (a.upperBound.y < b.lowerBound.y || a.lowerBound.y > b.upperBound.y)
        return false;
    if (a.upperBound.z < b.lowerBound.z || a.lowerBound.z > b.upperBound.z)
        return false;

    // Overlapping on all axis means bounds are intersecting
    return true;
}

/// Transform an axis-aligned bounding box. This can create a larger box
/// than if you recomputed the AABB of the original shape with the transform
/// applied.
pragma(inline, true) b3AABB b3AABB_Transform(b3Transform transform, b3AABB a)
{
    immutable b3Vec3 center = b3TransformPoint(transform, b3AABB_Center(a));
    immutable b3Matrix3 m = b3MakeMatrixFromQuat(transform.q);
    immutable b3Vec3 extent = b3MulMV(b3AbsMatrix3(m), b3AABB_Extents(a));
    return b3AABB(b3Sub(center, extent), b3Add(center, extent));
}

/// Get the closest point on an axis-aligned bounding box.
pragma(inline, true) b3Vec3 b3ClosestPointToAABB(b3Vec3 point, b3AABB a) => b3Clamp(point, a.lowerBound, a.upperBound);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

@safe unittest
{
    // Free-function vector arithmetic.
    immutable a = b3Vec3(1.0f, 2.0f, 3.0f);
    immutable b = b3Vec3(4.0f, 5.0f, 6.0f);
    assert(b3Add(a, b) == b3Vec3(5.0f, 7.0f, 9.0f));
    assert(b3Sub(b, a) == b3Vec3(3.0f, 3.0f, 3.0f));
    assert(b3Mul(a, b) == b3Vec3(4.0f, 10.0f, 18.0f));
    assert(b3Neg(a) == b3Vec3(-1.0f, -2.0f, -3.0f));
    assert(b3Dot(a, b) == 32.0f);
    assert(b3MulSV(2.0f, a) == b3Vec3(2.0f, 4.0f, 6.0f));
    assert(b3MulAdd(a, 2.0f, b) == b3Vec3(9.0f, 12.0f, 15.0f));
    assert(b3MulSub(a, 1.0f, b) == b3Vec3(-3.0f, -3.0f, -3.0f));
}

@safe unittest
{
    // Operator overloads mirror the free functions.
    immutable a = b3Vec3(1.0f, 2.0f, 3.0f);
    immutable b = b3Vec3(4.0f, 5.0f, 6.0f);
    assert(a + b == b3Vec3(5.0f, 7.0f, 9.0f));
    assert(b - a == b3Vec3(3.0f, 3.0f, 3.0f));
    assert(2.0f * a == b3Vec3(2.0f, 4.0f, 6.0f));
    assert(a * 2.0f == b3Vec3(2.0f, 4.0f, 6.0f));
    assert(-a == b3Vec3(-1.0f, -2.0f, -3.0f));

    b3Vec3 c = a;
    c += b;
    c -= a;
    c *= 2.0f;
    assert(c == b3Vec3(8.0f, 10.0f, 12.0f));
}

@safe unittest
{
    // Cross product follows the right-hand rule on the coordinate axes.
    assert(b3Cross(b3Vec3_axisX, b3Vec3_axisY) == b3Vec3_axisZ);
    assert(b3Cross(b3Vec3_axisY, b3Vec3_axisZ) == b3Vec3_axisX);
    assert(b3Cross(b3Vec3_axisZ, b3Vec3_axisX) == b3Vec3_axisY);
    assert(b3Cross(b3Vec3_axisX, b3Vec3_axisX) == b3Vec3_zero);
}

@safe unittest
{
    // Length, distance and normalization.
    immutable v = b3Vec3(2.0f, 3.0f, 6.0f);
    assert(b3LengthSquared(v) == 49.0f);
    assert(b3Length(v) == 7.0f);
    assert(b3Distance(b3Vec3_zero, v) == 7.0f);
    assert(b3DistanceSquared(b3Vec3_zero, v) == 49.0f);

    immutable n = b3Normalize(v);
    assert(b3AbsFloat(b3Length(n) - 1.0f) < 1.0e-5f);
    assert(b3IsNormalized(n));
    assert(b3Normalize(b3Vec3_zero) == b3Vec3_zero);
}

@safe unittest
{
    // Perpendicular vector is a unit vector orthogonal to the input.
    immutable a = b3Normalize(b3Vec3(1.0f, 2.0f, 3.0f));
    immutable p = b3Perp(a);
    assert(b3IsNormalized(p));
    assert(b3AbsFloat(b3Dot(a, p)) < 1.0e-5f);
}

@safe unittest
{
    // Component-wise helpers.
    immutable a = b3Vec3(-1.0f, 2.0f, -3.0f);
    immutable b = b3Vec3(0.0f, 1.0f, 4.0f);
    assert(b3Abs(a) == b3Vec3(1.0f, 2.0f, 3.0f));
    assert(b3Sign(a) == b3Vec3(-1.0f, 1.0f, -1.0f));
    assert(b3Min(a, b) == b3Vec3(-1.0f, 1.0f, -3.0f));
    assert(b3Max(a, b) == b3Vec3(0.0f, 2.0f, 4.0f));
    assert(b3Clamp(a, b3Vec3(0.0f, 0.0f, 0.0f), b3Vec3(1.0f, 1.0f, 1.0f)) == b3Vec3(0.0f, 1.0f, 0.0f));
    assert(b3SafeScale(b3Vec3(0.0f, -0.001f, 2.0f)) == b3Vec3(B3_MIN_SCALE, -B3_MIN_SCALE, 2.0f));
}

@safe unittest
{
    // Identity quaternion leaves vectors and quaternions unchanged.
    immutable v = b3Vec3(2.0f, -3.0f, 4.0f);
    assert(b3RotateVector(b3Quat_identity, v) == v);
    assert(b3InvRotateVector(b3Quat_identity, v) == v);
    assert(b3IsNormalizedQuat(b3Quat_identity));

    immutable q = b3MulQuat(b3Quat_identity, b3Quat_identity);
    assert(q.v == b3Vec3_zero && q.s == 1.0f);
    assert(b3Conjugate(b3Quat_identity).s == 1.0f);
    assert(b3DotQuat(b3Quat_identity, b3Quat_identity) == 1.0f);

    // Normalization rescales a scaled identity back to the identity.
    immutable n = b3NormalizeQuat(b3Quat(b3Vec3_zero, 2.0f));
    assert(n.v == b3Vec3_zero && n.s == 1.0f);
    assert(b3NormalizeQuat(b3Quat(b3Vec3_zero, 0.0f)) == b3Quat_identity);
}

@safe unittest
{
    // Transform composition and point transformation.
    immutable v = b3Vec3(1.0f, 2.0f, 3.0f);
    assert(b3TransformPoint(b3Transform_identity, v) == v);

    immutable t = b3Transform(b3Vec3(10.0f, 20.0f, 30.0f), b3Quat_identity);
    immutable w = b3TransformPoint(t, v);
    assert(w == b3Vec3(11.0f, 22.0f, 33.0f));
    assert(b3InvTransformPoint(t, w) == v);

    immutable inv = b3InvertTransform(t);
    assert(b3TransformPoint(inv, w) == v);

    immutable m = b3MulTransforms(t, inv);
    assert(m.p == b3Vec3_zero && m.q.s == 1.0f);
}

@safe unittest
{
    // World position helpers collapse to plain float operations.
    immutable v = b3Vec3(1.0f, 2.0f, 3.0f);
    assert(b3ToVec3(b3ToPos(v)) == v);
    assert(b3SubPos(b3ToPos(v), b3Pos_zero) == v);
    assert(b3OffsetPos(b3Pos_zero, v) == b3ToPos(v));
    assert(b3LerpPosition(b3Pos_zero, b3ToPos(v), 1.0f) == b3ToPos(v));
    assert(b3MakeWorldTransform(b3Transform_identity) == b3WorldTransform_identity);
}

@safe unittest
{
    // Matrix operations on the identity.
    assert(b3Det(b3Mat3_identity) == 1.0f);
    immutable v = b3Vec3(1.0f, 2.0f, 3.0f);
    assert(b3MulMV(b3Mat3_identity, v) == v);
    assert(b3Transpose(b3Mat3_identity) == b3Mat3_identity);
    assert(b3InvertMatrix(b3Mat3_identity) == b3Mat3_identity);
    assert(b3Solve3(b3Mat3_identity, v) == v);
    assert(b3InvertMatrix(b3Mat3_zero) == b3Mat3_zero);
    assert(b3Solve3(b3Mat3_zero, v) == b3Vec3_zero);
    assert(b3MakeMatrixFromQuat(b3Quat_identity) == b3Mat3_identity);
}

@safe unittest
{
    // Matrix arithmetic.
    immutable m = b3MulSM(2.0f, b3Mat3_identity);
    assert(b3AddMM(b3Mat3_identity, b3Mat3_identity) == m);
    assert(b3SubMM(m, b3Mat3_identity) == b3Mat3_identity);
    assert(b3MulMM(b3Mat3_identity, m) == m);
    assert(b3NegateMat3(b3Mat3_zero) == b3Mat3_zero);
    assert(b3AbsMatrix3(b3NegateMat3(b3Mat3_identity)) == b3Mat3_identity);
}

@safe unittest
{
    // AABB containment, union, overlap and metrics.
    immutable outer = b3AABB(b3Vec3(0, 0, 0), b3Vec3(10, 10, 10));
    immutable inner = b3AABB(b3Vec3(2, 2, 2), b3Vec3(5, 5, 5));
    assert(b3AABB_Contains(outer, inner));
    assert(!b3AABB_Contains(inner, outer));
    assert(b3AABB_Overlaps(outer, inner));
    assert(b3AABB_Center(outer) == b3Vec3(5, 5, 5));
    assert(b3AABB_Extents(outer) == b3Vec3(5, 5, 5));
    assert(b3AABB_Area(b3AABB(b3Vec3(0, 0, 0), b3Vec3(1, 2, 3))) == 22.0f);

    immutable u = b3AABB_Union(b3AABB(b3Vec3(0, 0, 0), b3Vec3(1, 1, 1)), b3AABB(b3Vec3(2, 2, 2), b3Vec3(3, 3, 3)));
    assert(u.lowerBound == b3Vec3(0, 0, 0) && u.upperBound == b3Vec3(3, 3, 3));

    immutable inflated = b3AABB_Inflate(inner, 1.0f);
    assert(inflated.lowerBound == b3Vec3(1, 1, 1) && inflated.upperBound == b3Vec3(6, 6, 6));

    assert(b3ClosestPointToAABB(b3Vec3(20, -1, 3), outer) == b3Vec3(10, 0, 3));
}

@safe unittest
{
    // AABB transform with the identity is an offset by the translation.
    immutable box = b3AABB(b3Vec3(-1, -1, -1), b3Vec3(1, 1, 1));
    immutable t = b3Transform(b3Vec3(5.0f, 0.0f, 0.0f), b3Quat_identity);
    immutable moved = b3AABB_Transform(t, box);
    assert(moved.lowerBound == b3Vec3(4, -1, -1) && moved.upperBound == b3Vec3(6, 1, 1));

    assert(b3OffsetAABB(box, b3ToPos(b3Vec3(5.0f, 0.0f, 0.0f))) == moved);
}

@safe unittest
{
    // Point cloud AABB.
    immutable b3Vec3[3] points = [b3Vec3(0, 0, 0), b3Vec3(1, 5, 2), b3Vec3(-1, 2, 4)];
    immutable a = (() @trusted => b3MakeAABB(points.ptr, 3, 1.0f))();
    assert(a.lowerBound == b3Vec3(-2, -1, -1));
    assert(a.upperBound == b3Vec3(2, 6, 5));
}

@safe unittest
{
    // Integer helpers.
    assert(b3MinInt(3, 7) == 3);
    assert(b3MaxInt(3, 7) == 7);
    assert(b3ClampInt(9, 0, 5) == 5);
    assert(b3ClampInt(-1, 0, 5) == 0);
    assert(b3ClampInt(3, 0, 5) == 3);
}

@safe unittest
{
    // Float helpers.
    assert(b3MinFloat(3.0f, 7.0f) == 3.0f);
    assert(b3MaxFloat(3.0f, 7.0f) == 7.0f);
    assert(b3AbsFloat(-4.0f) == 4.0f);
    assert(b3ClampFloat(9.0f, 0.0f, 5.0f) == 5.0f);
    assert(b3LerpFloat(2.0f, 4.0f, 0.5f) == 3.0f);
    assert(b3Blend2(2.0f, b3Vec3_axisX, 3.0f, b3Vec3_axisY) == b3Vec3(2.0f, 3.0f, 0.0f));
    assert(b3Lerp(b3Vec3_zero, b3Vec3(2, 4, 6), 0.5f) == b3Vec3(1, 2, 3));
}
