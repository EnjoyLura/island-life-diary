shader_type spatial;
render_mode shading_model_unlit, cull_disabled;
uniform float swim_time = 0.0;
// x: RGBA8 low-nibble mesh slot, y: gape, z: fight load, w: tail phase.
uniform vec4 fish_action = vec4(-1.0,0.0,0.0,0.0);
varying vec3 fish_local;
void vertex() {
    fish_local=VERTEX;
    float weight=pow(clamp((.43-VERTEX.z)/1.5,0.0,1.0),1.65);
    float slot=mod(floor(COLOR.a*255.0+.5),16.0);
    float selected=1.0-smoothstep(.25,.5,abs(slot-fish_action.x));
    float phase=mix(swim_time*6.2+COLOR.a*38.0,fish_action.w,selected)+VERTEX.z*6.5;
    VERTEX.x+=sin(phase)*weight*.115*(1.0+selected*fish_action.z*.45);
    float lower_lip=(1.0-smoothstep(-.08,.02,VERTEX.y))*smoothstep(.35,.63,VERTEX.z);
    VERTEX.y-=selected*fish_action.y*lower_lip*.12;
    // Bend the whole rear body and vertical caudal fin, not a rigid fish pivot.
    NORMAL=normalize(vec3(NORMAL.x,NORMAL.y,NORMAL.z-cos(phase)*weight*.34*NORMAL.x));
}
void fragment() {
    float band=smoothstep(-.30,.55,dot(normalize(NORMAL),normalize(vec3(-.35,.9,-.25))));
    band=floor(band*3.0+.25)/3.0;
    vec3 color=COLOR.rgb*mix(vec3(.66,.83,.93),vec3(1.12,1.08,.96),band);
    float species=floor(COLOR.a*16.0);
    float flank=smoothstep(.035,.13,abs(fish_local.x));
    if(species==3.0 || species==5.0) {
        float stripes=smoothstep(.58,.82,sin(fish_local.z*39.0+fish_local.y*9.0));
        color*=1.0-stripes*.23*flank*smoothstep(-.01,.12,fish_local.y);
    }
    if(species==7.0) {
        vec2 spots=fract(vec2(fish_local.z*13.0,fish_local.y*16.0));
        color*=1.0-(1.0-smoothstep(.12,.24,length(spots-.5)))*.32*flank;
    }
    ALBEDO=pow(max(color,vec3(0.0)),vec3(2.2));
}
