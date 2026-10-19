#ifndef CLEAR_COAT_ENVIRONMENT_SH
#define CLEAR_COAT_ENVIRONMENT_SH

/// Remap indirect material colors as UE ClearCoatCommon.ush does before reflection composition.
/// specularColor contains the original metallic-workflow F0 on input; diffuseColor is replaced.
/// noV is the top-layer cosine. The returned colors already include the diffuse layer attenuation.
void RemapClearCoatEnvironmentColors(hvec3 baseColor, hfloat metallic, hfloat roughness, hfloat noV,
    hfloat coverage, out hvec3 diffuseColor, inout hvec3 specularColor)
{
    hfloat refractionScale = ((noV * 0.5 + 0.5) * noV - 1.0) * saturate(1.25 - 1.25 * roughness) + 1.0;
    hvec3 absorptionColor = baseColor / 0.9;
    hvec3 absorption = absorptionColor * ((noV - 1.0) * 0.85 *
        (hvec3_init(1.0, 1.0, 1.0) - mix(absorptionColor, absorptionColor * absorptionColor, -0.78)) + hvec3_init(1.0, 1.0, 1.0));
    hfloat fresnel = 0.04 + 0.96 * pow(1.0 - noV, 5.0);
    hvec3 remappedBase = mix(baseColor * (1.0 - fresnel * coverage),
        0.9 * absorption * refractionScale, metallic * coverage);
    diffuseColor = remappedBase * (1.0 - metallic);
    // Reweight the original dielectric F0 without dividing by 1-metallic at the metal endpoint.
    hvec3 dielectricF0 = hvec3_init(0.08, 0.08, 0.08);
    specularColor = (specularColor - baseColor * metallic) * (1.0 - coverage) +
        dielectricF0 * (refractionScale * coverage * (1.0 - metallic)) + remappedBase * metallic;
}

#endif
