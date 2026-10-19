// Procedural gradient sky with a sun disc and glow, ported from Godot 4.6
// ProceduralSkyMaterial (scene/resources/3d/sky_material.cpp, MIT). Driven by
// the ProceduralSky component, which converts its user-facing parameters with
// Godot's formulas (colors pre-multiplied by energy, curve inversions, cosines)
// and supplies the bound directional light as sun_* uniforms (Godot: LIGHT0_*).
// The disc radiance equals the glow's peak, so unlike UE's sky there is no hot
// spot to strip from environment captures.
shader_type sky;

uniform vec3 sky_top_color = vec3(0.385, 0.454, 0.55);
uniform vec3 sky_horizon_color = vec3(0.6463, 0.6558, 0.6708);
uniform float inv_sky_curve = 4.0;
uniform vec3 ground_bottom_color = vec3(0.2, 0.169, 0.133);
uniform vec3 ground_horizon_color = vec3(0.6463, 0.6558, 0.6708);
uniform float inv_ground_curve = 30.0;
uniform float sun_angle_max = 0.866;
uniform float inv_sun_curve = 22.78;
uniform float exposure = 1.0;

// Bound sun; sun_enabled is 0 when no light is bound. sun_direction points towards the sun.
uniform float sun_enabled = 0.0;
uniform vec3 sun_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 sun_color = vec3(1.0);
uniform float sun_size = 0.99998;

void sky() {
    float v_angle = clamp(EYEDIR.y, -1.0, 1.0);
    vec3 sky = mix(sky_top_color, sky_horizon_color, clamp(pow(1.0 - v_angle, inv_sky_curve), 0.0, 1.0));

    if (sun_enabled > 0.5) {
        float sun_angle = dot(sun_direction, EYEDIR);
        if (sun_angle > sun_size) {
            sky = sun_color;
        } else if (sun_angle > sun_angle_max) {
            float c2 = (sun_size - sun_angle) / (sun_size - sun_angle_max);
            sky = mix(sky, sun_color, clamp(pow(1.0 - c2, inv_sun_curve), 0.0, 1.0));
        }
    }

    vec3 ground = mix(ground_bottom_color, ground_horizon_color, clamp(pow(1.0 + v_angle, inv_ground_curve), 0.0, 1.0));

    COLOR = mix(ground, sky, step(0.0, EYEDIR.y)) * exposure;
    ALPHA = 1.0;
}
