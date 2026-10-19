hvec2 vTexCoord      : TEXCOORD5 = hvec2_init(0.0, 0.0);
vec4 vColor          : COLOR0    = vec4(1.0, 1.0, 1.0, 1.0);
vec4 vDarkColor      : COLOR1    = vec4(0.0, 0.0, 0.0, 1.0);
hvec4 vScreenPos     : TEXCOORD1 = hvec4_init(0.0, 0.0, 0.0, 0.0);

hvec4 a_position  : POSITION;
hvec2 a_texcoord0 : TEXCOORD0;
hvec4 a_color0    : COLOR0;
hvec4 a_color1    : COLOR1;
