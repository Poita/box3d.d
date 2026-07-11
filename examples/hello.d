// SPDX-License-Identifier: MIT
/++
    Minimal Box3D example: a dynamic box falling onto static ground.

    Build and run with:
    ---
    dub run box3d:hello
    ---
+/
module hello;

import std.stdio : writefln;

import box3d;

void main()
{
    b3WorldDef worldDef = b3DefaultWorldDef();
    worldDef.gravity = b3Vec3(0.0f, -10.0f, 0.0f);
    b3WorldId world = b3CreateWorld(&worldDef);
    scope (exit)
        b3DestroyWorld(world);

    // Static ground.
    b3BodyDef groundDef = b3DefaultBodyDef();
    groundDef.position = b3Vec3(0.0f, -10.0f, 0.0f);
    b3BodyId ground = b3CreateBody(world, &groundDef);
    b3BoxHull groundBox = b3MakeBoxHull(50.0f, 10.0f, 50.0f);
    b3ShapeDef groundShape = b3DefaultShapeDef();
    b3CreateHullShape(ground, &groundShape, &groundBox.base);

    // A falling box.
    b3BodyDef bodyDef = b3DefaultBodyDef();
    bodyDef.type = b3BodyType.b3_dynamicBody;
    bodyDef.position = b3Vec3(0.0f, 8.0f, 0.0f);
    b3BodyId box = b3CreateBody(world, &bodyDef);
    b3BoxHull dynamicBox = b3MakeCubeHull(0.5f);
    b3ShapeDef shapeDef = b3DefaultShapeDef();
    shapeDef.density = 1.0f;
    b3CreateHullShape(box, &shapeDef, &dynamicBox.base);

    foreach (i; 0 .. 90)
    {
        b3World_Step(world, 1.0f / 60.0f, 4);
        b3Vec3 p = b3Body_GetPosition(box);
        writefln("step %2d: box at (%6.3f, %6.3f, %6.3f)", i, p.x, p.y, p.z);
    }
}
