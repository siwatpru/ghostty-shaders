// tft_ca_bloom_lite.glsl  —  Lightweight version with reduced GPU usage

// Shadertoy uniforms expected: iResolution, iTime, iChannel0, iFrame

/********** Tunables **********/
float resolution      = 4.0;   // TFT "pixel" size
float strength        = 0.4;   // scanline/grille strength (0..1)
float ca_offset_px    = 2.0;   // chromatic aberration offset in pixels (0=off)
float noise_amp       = 0.0;   // disabled for performance (set to 0.03 to enable)
float bloom_general   = 0.15;  // reduced bloom intensity
/******************************/

// TFT scanline/grille mask
void _scanline(inout vec3 color, vec2 uv)
{
    float scanline = step(1.2, mod(uv.y * iResolution.y, resolution));
    float grille   = step(1.2, mod(uv.x * iResolution.x, resolution));
    color *= max(1.0 - strength, scanline * grille);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // --- Base sampling with chromatic aberration ---
    vec2 eps = vec2(ca_offset_px / iResolution.x, 0.0);
    vec3 col;
    col.r = texture(iChannel0, uv + eps).r;
    col.g = texture(iChannel0, uv       ).g;
    col.b = texture(iChannel0, uv - eps ).b;

    // --- Simplified bloom (3x3 instead of 5x5) ---
    if (bloom_general > 0.0) {
        vec3 bloom = vec3(0.0);
        float pixelSize = 1.5 / iResolution.x;
        for (float x = -1.0; x <= 1.0; x += 1.0) {
            for (float y = -1.0; y <= 1.0; y += 1.0) {
                vec2 offset = vec2(x, y) * pixelSize;
                bloom += texture(iChannel0, uv + offset).rgb;
            }
        }
        bloom /= 9.0; // 3x3 samples
        col = mix(col, col + bloom, bloom_general);
    }


    // --- Apply TFT scanlines/grille ---
    _scanline(col, uv);

    fragColor = vec4(col, 1.0);
}
