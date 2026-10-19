#include "EnvBake/varying_envbake.def.sc"
$input v_texcoord0
#include "Common/common.sh"

SAMPLERCUBE(s_tex0, 0);
uniform hvec4 u_EnvBakeFace;

void main()
{
    hvec2 p = v_texcoord0 * 2.0 - 1.0;
    int face = int(u_EnvBakeFace.x);
    hvec3 ray;
    if (face == 0) ray = hvec3_init(1.0, -p.y, -p.x);
    else if (face == 1) ray = hvec3_init(-1.0, -p.y, p.x);
    else if (face == 2) ray = hvec3_init(p.x, 1.0, p.y);
    else if (face == 3) ray = hvec3_init(p.x, -1.0, -p.y);
    else if (face == 4) ray = hvec3_init(p.x, -p.y, 1.0);
    else ray = hvec3_init(-p.x, -p.y, -1.0);
    // Zone retains its legacy LOD distribution; only storage resolution/format changes.
    gl_FragColor = textureCubeLod(s_tex0, ray, u_EnvBakeFace.y);
}
