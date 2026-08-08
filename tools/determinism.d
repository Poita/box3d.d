// SPDX-License-Identifier: MIT
/++
    Cross-platform determinism harness for Box3D.

    Runs a fixed scene and prints a bitwise hash of every body's transform and
    velocity after each step. Two platforms that agree on every line simulate
    identically; the first differing line is the frame where they diverged.

    Also drives Box3D's own recording gate: a recording embeds the state hashes
    produced by the machine that recorded it, so replaying one machine's
    recording on another re-simulates and compares against those hashes.

    ---
    dub run box3d:determinism -- --out hashes.txt --record scene.b3rec
    dub run box3d:determinism -- --replay scene.b3rec
    ---
+/
module determinism;

import std.getopt : defaultGetoptPrinter, getopt;
import std.stdio : File, stderr, stdout, writefln;
import std.string : toStringz;

import box3d;

/// Number of simulated steps. Long enough for the stack to collapse, slide down
/// the ramp and settle, which is where small rounding differences amplify.
enum int defaultFrames = 600;

enum float timeStep = 1.0f / 60.0f;
enum int subStepCount = 4;

// ---------------------------------------------------------------------------
// Deterministic PRNG
// ---------------------------------------------------------------------------

/++
    xorshift32. The scene layout must be identical on every platform, so it
    cannot come from `std.random` or libc `rand`, whose algorithms and seeding
    are implementation-defined.
+/
struct Rng
{
    private uint state = 0x9E3779B9;

    /// Next raw 32-bit value.
    uint nextUint()
    {
        state ^= state << 13;
        state ^= state >> 17;
        state ^= state << 5;
        return state;
    }

    /++
        Uniform float in [lo, hi). Built from a 24-bit mantissa so the integer to
        float conversion is exact and the scaling is a single rounded multiply.
    +/
    float next(float lo, float hi)
    {
        immutable float unit = cast(float)(nextUint() >> 8) * (1.0f / 16_777_216.0f);
        return lo + unit * (hi - lo);
    }
}

// ---------------------------------------------------------------------------
// State hashing
// ---------------------------------------------------------------------------

/// FNV-1a 64-bit. Chosen because it is trivially reimplementable in any language
/// a reader might want to cross-check with.
struct Fnv1a
{
    private ulong hash = 0xCBF2_9CE4_8422_2325UL;

    /// Fold in one byte.
    void put(ubyte b)
    {
        hash ^= b;
        hash *= 0x1000_0000_01B3UL;
    }

    /// Fold in the raw bits of a float. Hashing bits rather than the value makes
    /// the comparison exact rather than within a tolerance.
    void put(float f)
    {
        immutable uint bits = floatBits(f);
        foreach (i; 0 .. 4)
            put(cast(ubyte)(bits >> (8 * i)));
    }

    /// Fold in a vector.
    void put(b3Vec3 v)
    {
        put(v.x);
        put(v.y);
        put(v.z);
    }

    /// Fold in a quaternion.
    void put(b3Quat q)
    {
        put(q.v);
        put(q.s);
    }

    /// The accumulated hash.
    ulong value() const => hash;
}

/// Reinterpret a float's storage as an integer.
private uint floatBits(float f) @trusted
{
    union Bits
    {
        float f;
        uint u;
    }

    Bits b = {f: f};
    return b.u;
}

/// True when any component is NaN.
private bool hasNaN(b3Vec3 v) => v.x != v.x || v.y != v.y || v.z != v.z;

// ---------------------------------------------------------------------------
// Scene
// ---------------------------------------------------------------------------

/++
    Builds the reference scene into `world` and returns its dynamic bodies in
    creation order.

    The scene mixes hulls, spheres and capsules resting on a tilted ramp so the
    run exercises several manifold generators, the contact solver, continuous
    collision and sleeping rather than a single code path.
+/
b3BodyId[] buildScene(b3WorldId world)
{
    // Ground.
    b3BodyDef groundDef = b3DefaultBodyDef();
    groundDef.position = b3Vec3(0.0f, -1.0f, 0.0f);
    b3BodyId ground = b3CreateBody(world, &groundDef);
    b3BoxHull groundBox = b3MakeBoxHull(50.0f, 1.0f, 50.0f);
    b3ShapeDef groundShape = b3DefaultShapeDef();
    b3CreateHullShape(ground, &groundShape, &groundBox.base);

    // Ramp, tilted about z so the stack slides as well as falls.
    b3BodyDef rampDef = b3DefaultBodyDef();
    rampDef.position = b3Vec3(0.0f, 2.0f, 0.0f);
    rampDef.rotation = b3MakeQuatFromAxisAngle(b3Vec3(0.0f, 0.0f, 1.0f), 0.35f);
    b3BodyId ramp = b3CreateBody(world, &rampDef);
    b3BoxHull rampBox = b3MakeBoxHull(12.0f, 0.5f, 12.0f);
    b3ShapeDef rampShape = b3DefaultShapeDef();
    b3CreateHullShape(ramp, &rampShape, &rampBox.base);

    // Dynamic bodies in a lattice, jittered so contacts do not all form on the
    // same step.
    Rng rng;
    b3BodyId[] bodies;

    foreach (layer; 0 .. 4)
    {
        foreach (row; 0 .. 4)
        {
            foreach (column; 0 .. 4)
            {
                b3BodyDef bodyDef = b3DefaultBodyDef();
                bodyDef.type = b3BodyType.b3_dynamicBody;
                bodyDef.position = b3Vec3(-3.0f + 2.0f * column + rng.next(-0.15f, 0.15f), 6.0f + 1.6f * layer,
                        -3.0f + 2.0f * row + rng.next(-0.15f, 0.15f));
                // The z component is kept away from zero so the axis is never
                // degenerate and b3Normalize always returns a unit vector.
                bodyDef.rotation = b3MakeQuatFromAxisAngle(b3Normalize(b3Vec3(rng.next(-1.0f, 1.0f),
                        rng.next(-1.0f, 1.0f), rng.next(0.5f, 1.5f))), rng.next(-1.0f, 1.0f));
                bodyDef.angularVelocity = b3Vec3(rng.next(-2.0f, 2.0f), rng.next(-2.0f, 2.0f), rng.next(-2.0f, 2.0f));
                bodyDef.enableSleep = true;

                b3BodyId body_ = b3CreateBody(world, &bodyDef);
                b3ShapeDef shapeDef = b3DefaultShapeDef();
                shapeDef.density = 1.0f;

                final switch ((layer + row + column) % 3)
                {
                case 0:
                    b3BoxHull hull = b3MakeCubeHull(0.5f);
                    b3CreateHullShape(body_, &shapeDef, &hull.base);
                    break;
                case 1:
                    b3Sphere sphere = b3Sphere(b3Vec3(0.0f, 0.0f, 0.0f), 0.5f);
                    b3CreateSphereShape(body_, &shapeDef, &sphere);
                    break;
                case 2:
                    b3Capsule capsule = b3Capsule(b3Vec3(0.0f, -0.25f, 0.0f), b3Vec3(0.0f, 0.25f, 0.0f), 0.35f);
                    b3CreateCapsuleShape(body_, &shapeDef, &capsule);
                    break;
                }

                bodies ~= body_;
            }
        }
    }

    return bodies;
}

/// Hashes every body's transform and velocity in creation order.
ulong hashState(const b3BodyId[] bodies, int frame)
{
    Fnv1a hash;

    foreach (body_; bodies)
    {
        b3WorldTransform transform = b3Body_GetTransform(body_);
        b3Vec3 linear = b3Body_GetLinearVelocity(body_);
        b3Vec3 angular = b3Body_GetAngularVelocity(body_);

        // A NaN would make the hash meaningless to compare: quiet NaN payloads
        // differ between architectures even when the simulation agrees.
        if (hasNaN(transform.p) || hasNaN(linear) || hasNaN(angular))
        {
            stderr.writefln("NaN in body state at frame %d; scene is unusable as a gate", frame);
            assert(false, "NaN in simulation state");
        }

        hash.put(transform.p);
        hash.put(transform.q);
        hash.put(linear);
        hash.put(angular);
    }

    return hash.value;
}

// ---------------------------------------------------------------------------
// Modes
// ---------------------------------------------------------------------------

/// Runs the scene, writing one hash line per frame and optionally a recording.
void runScene(string outPath, string recordPath, int frames)
{
    b3WorldDef worldDef = b3DefaultWorldDef();
    worldDef.gravity = b3Vec3(0.0f, -10.0f, 0.0f);
    // Replay is single threaded, so record single threaded too.
    worldDef.workerCount = 1;
    b3WorldId world = b3CreateWorld(&worldDef);
    scope (exit)
        b3DestroyWorld(world);

    b3Recording* recording;
    if (recordPath.length)
    {
        // Started before the bodies exist so their creation is part of the op
        // stream rather than the seed snapshot.
        recording = b3CreateRecording(16 * 1024 * 1024);
        b3World_StartRecording(world, recording);
    }
    scope (exit)
    {
        if (recording !is null)
            b3DestroyRecording(recording);
    }

    b3BodyId[] bodies = buildScene(world);

    File output = outPath.length ? File(outPath, "w") : stdout;
    // dt is printed as raw bits rather than %a: the header is compared verbatim
    // across platforms, so it must not depend on float formatting.
    output.writefln("# box3d determinism hashes: %d bodies, %d frames, dt=0x%08x, substeps=%d",
            bodies.length, frames, floatBits(timeStep), subStepCount);

    foreach (frame; 0 .. frames)
    {
        b3World_Step(world, timeStep, subStepCount);
        output.writefln("%04d %016x", frame, hashState(bodies, frame));
    }

    if (outPath.length)
        output.close();

    if (recording !is null)
    {
        b3World_StopRecording(world);
        if (!b3SaveRecordingToFile(recording, recordPath.toStringz))
        {
            stderr.writefln("failed to write recording to %s", recordPath);
            assert(false, "recording write failed");
        }
        writefln("wrote recording (%d bytes) to %s", b3Recording_GetSize(recording), recordPath);
    }
}

/++
    Replays a recording and checks it against the state hashes embedded by the
    machine that produced it. Returns true when every frame matched.
+/
bool replayRecording(string path)
{
    b3Recording* recording = b3LoadRecordingFromFile(path.toStringz);
    if (recording is null)
    {
        stderr.writefln("could not load recording %s", path);
        return false;
    }
    scope (exit)
        b3DestroyRecording(recording);

    immutable int size = b3Recording_GetSize(recording);
    // b3ValidateReplay documents workerCount as reserved; pass 1.
    immutable bool ok = b3ValidateReplay(b3Recording_GetData(recording), size, 1);

    if (ok)
        writefln("replay of %s matched all embedded state hashes (%d bytes)", path, size);
    else
        stderr.writefln("replay of %s DIVERGED from its embedded state hashes", path);

    return ok;
}

// ---------------------------------------------------------------------------

int main(string[] args)
{
    string outPath;
    string recordPath;
    string replayPath;
    int frames = defaultFrames;

    auto help = getopt(args, "out|o", "Write per-frame state hashes to this file (default: stdout)",
            &outPath, "record|r", "Save a Box3D recording of the run to this file",
            &recordPath, "replay", "Replay a recording and verify its embedded state hashes",
            &replayPath, "frames|n", "Number of steps to simulate", &frames);

    if (help.helpWanted)
    {
        defaultGetoptPrinter("Box3D cross-platform determinism harness", help.options);
        return 0;
    }

    if (replayPath.length)
        return replayRecording(replayPath) ? 0 : 1;

    runScene(outPath, recordPath, frames);
    return 0;
}
