// World-aligned cube face directions shared by sky and cloud environment capture.
#ifndef URHO_ATMOSPHERE_CAPTURE_COMMON
#define URHO_ATMOSPHERE_CAPTURE_COMMON

hvec3 AtmosphereCaptureDirection(int face, hvec2 uv)
{
    hvec2 p = uv * 2.0 - 1.0;
    if (face == 0) return hvec3_init(1.0, -p.y, -p.x);
    if (face == 1) return hvec3_init(-1.0, -p.y, p.x);
    if (face == 2) return hvec3_init(p.x, 1.0, p.y);
    if (face == 3) return hvec3_init(p.x, -1.0, -p.y);
    if (face == 4) return hvec3_init(p.x, -p.y, 1.0);
    return hvec3_init(-p.x, -p.y, -1.0);
}

#endif
