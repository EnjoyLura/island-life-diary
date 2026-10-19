// UE 5.5.4 SkyAtmosphere.usf / SkyAtmosphereCommon.ush, with local Y-up coordinates.
#ifndef URHO_SKY_ATMOSPHERE_SKY_VIEW
#define URHO_SKY_ATMOSPHERE_SKY_VIEW

uniform hvec4 u_AtmosphereAPCamera;
uniform hvec4 u_AtmosphereSkyViewForward;
uniform hvec4 u_AtmosphereSkyViewLeft;
uniform hvec4 u_AtmosphereSkyViewUp;
uniform hvec4 u_AtmosphereViewOptions; // render sky, min/max samples, inverse distance to max samples

// UE FastMathThirdParty.ush acosFast4 and atan2Fast.
hfloat AtmosphereAcos(hfloat x)
{
    x = clamp(x, -1.0, 1.0);
    hfloat a = abs(x);
    hfloat s = -0.2121144 * a + 1.5707288;
    s += 0.0742610 * a * a;
    s -= 0.0187293 * a * a * a;
    s *= sqrt(1.0 - a);
    return x >= 0.0 ? s : 3.14159265359 - s;
}

hfloat AtmosphereAtan2(hfloat y, hfloat x)
{
    hfloat m = max(abs(x), abs(y));
    hfloat t = m > 0.0 ? min(abs(x), abs(y)) / m : 0.0;
    hfloat t2 = t * t;
    t *= (0.0872929 * t2 - 0.301895) * t2 + 1.0;
    t = abs(y) > abs(x) ? 1.570796326795 - t : t;
    t = x < 0.0 ? 3.14159265359 - t : t;
    return y < 0.0 ? -t : t;
}

hvec3 AtmosphereSkyViewDirection(hvec2 uv, hfloat height)
{
    hvec2 size = hvec2_init(192.0, 104.0);
    uv = (uv - 0.5 / size) * size / (size - 1.0);
    hfloat horizon = sqrt(max(0.0, height * height - u_AtmosphereRadii.x * u_AtmosphereRadii.x));
    hfloat beta = AtmosphereAcos(horizon / height);
    hfloat zenithHorizon = 3.14159265359 - beta;
    hfloat coord = uv.y < 0.5 ? 1.0 - 2.0 * uv.y : 2.0 * uv.y - 1.0;
    hfloat angle = uv.y < 0.5 ? zenithHorizon * (1.0 - coord * coord) : zenithHorizon + beta * coord * coord;
    hfloat cy = cos(angle);
    hfloat sy = sqrt(max(0.0, 1.0 - cy * cy)) * (angle > 0.0 ? 1.0 : -1.0);
    hfloat longitude = uv.x * 6.28318530718;
    hfloat cx = cos(longitude);
    hfloat sx = sqrt(max(0.0, 1.0 - cx * cx)) * (longitude <= 3.14159265359 ? 1.0 : -1.0);
    return hvec3_init(sy * cx, cy, sy * sx);
}

hvec2 AtmosphereSkyViewUV(hvec3 direction, hfloat height, bool ground)
{
    hvec3 localDir = hvec3_init(dot(direction, u_AtmosphereSkyViewForward.xyz),
        dot(direction, u_AtmosphereSkyViewUp.xyz), dot(direction, u_AtmosphereSkyViewLeft.xyz));
    hfloat horizon = sqrt(max(0.0, height * height - u_AtmosphereRadii.x * u_AtmosphereRadii.x));
    hfloat beta = AtmosphereAcos(horizon / height);
    hfloat zenithHorizon = 3.14159265359 - beta;
    hfloat viewAngle = AtmosphereAcos(localDir.y);
    hfloat v = !ground ? 0.5 * (1.0 - sqrt(saturate(1.0 - viewAngle / zenithHorizon)))
        : 0.5 + 0.5 * sqrt(saturate((viewAngle - zenithHorizon) / beta));
    hfloat u = (AtmosphereAtan2(-localDir.z, -localDir.x) + 3.14159265359) / 6.28318530718;
    hvec2 size = hvec2_init(192.0, 104.0);
    return (hvec2_init(u, v) + 0.5 / size) * size / (size + 1.0);
}

#endif
