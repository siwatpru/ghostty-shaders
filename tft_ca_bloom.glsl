// tft_ca_bloom.glsl  —  TFT scanlines + mild CA + light noise (no warp, no glitch)

// Shadertoy uniforms expected: iResolution, iTime, iChannel0, iFrame

/********** Tunables **********/
float resolution      = 4.0;   // TFT "pixel" size
float strength        = 0.4;   // scanline/grille strength (0..1)
float ca_offset_px    = 2.0;   // chromatic aberration offset in pixels (0=off)
float noise_amp       = 0.04;  // film grain intensity (0..~0.08 is subtle)
float bloom_general   = 0.2;  // overall bloom intensity (all pixels)
float bloom_selective = 0.1;   // selective bloom for bright areas (text)
/******************************/

// Golden spiral samples for bloom, [x, y, weight]
const vec3[24] samples = {
  vec3(0.1693761725038636, 0.9855514761735895, 1),
  vec3(-1.333070830962943, 0.4721463328627773, 0.7071067811865475),
  vec3(-0.8464394909806497, -1.51113870578065, 0.5773502691896258),
  vec3(1.554155680728463, -1.2588090085709776, 0.5),
  vec3(1.681364377589461, 1.4741145918052656, 0.4472135954999579),
  vec3(-1.2795157692199817, 2.088741103228784, 0.4082482904638631),
  vec3(-2.4575847530631187, -0.9799373355024756, 0.3779644730092272),
  vec3(0.5874641440200847, -2.7667464429345077, 0.35355339059327373),
  vec3(2.997715703369726, 0.11704939884745152, 0.3333333333333333),
  vec3(0.41360842451688395, 3.1351121305574803, 0.31622776601683794),
  vec3(-3.167149933769243, 0.9844599011770256, 0.30151134457776363),
  vec3(-1.5736713846521535, -3.0860263079123245, 0.2886751345948129),
  vec3(2.888202648340422, -2.1583061557896213, 0.2773500981126146),
  vec3(2.7150778983300325, 2.5745586041105715, 0.2672612419124244),
  vec3(-2.1504069972377464, 3.2211410627650165, 0.2581988897471611),
  vec3(-3.6548858794907493, -1.6253643308191343, 0.25),
  vec3(1.0130775986052671, -3.9967078676335834, 0.24253562503633297),
  vec3(4.229723673607257, 0.33081361055181563, 0.23570226039551587),
  vec3(0.40107790291173834, 4.340407413572593, 0.22941573387056174),
  vec3(-4.319124570236028, 1.159811599693438, 0.22360679774997896),
  vec3(-1.9209044802827355, -4.160543952132907, 0.2182178902359924),
  vec3(3.8639122286635708, -2.6589814382925123, 0.21320071635561041),
  vec3(3.3486228404946234, 3.4331800232609, 0.20851441405707477),
  vec3(-2.8769733643574344, 3.9652268864187157, 0.20412414523193154)
};

float lum(vec3 c) {
  return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;
}

// Simple 2D hash for grain (stable, cheap)
float hash21(vec2 p) {
    // jitter per-frame a little to animate the grain
    p += float(iFrame) * 0.1234;
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// Your original TFT scanline/grille mask
void _scanline(inout vec3 color, vec2 uv)
{
    float scanline = step(1.2, mod(uv.y * iResolution.y, resolution));
    float grille   = step(1.2, mod(uv.x * iResolution.x, resolution));
    color *= max(1.0 - strength, scanline * grille);
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fragCoord / iResolution.xy;

    // --- Base sampling (no warp/distortion) ---
    // Chromatic aberration: small horizontal split of channels
    vec2 eps = vec2(ca_offset_px / iResolution.x, 0.0);
    vec3 col;
    col.r = texture(iChannel0, uv + eps).r;
    col.g = texture(iChannel0, uv       ).g;
    col.b = texture(iChannel0, uv - eps ).b;

    // --- General bloom (overall glow) ---
    if (bloom_general > 0.0) {
        vec3 bloom = vec3(0.0);
        float pixelSize = 1.5 / iResolution.x;
        for (float x = -2.0; x <= 2.0; x += 1.0) {
            for (float y = -2.0; y <= 2.0; y += 1.0) {
                vec2 offset = vec2(x, y) * pixelSize;
                bloom += texture(iChannel0, uv + offset).rgb;
            }
        }
        bloom /= 25.0; // 5x5 samples
        col = mix(col, col + bloom, bloom_general);
    }

    // --- Selective bloom for bright areas (text) ---
    if (bloom_selective > 0.0) {
        vec2 step = vec2(1.414) / iResolution.xy;
        for (int i = 0; i < 24; i++) {
            vec3 s = samples[i];
            vec3 c = texture(iChannel0, uv + s.xy * step).rgb;
            float l = lum(c);
            if (l > 0.2) {
                col += l * s.z * c * bloom_selective;
            }
        }
    }

    // --- Gentle film grain (animated, low level) ---
    float grain = hash21(fragCoord);
    col += (grain - 0.5) * 2.0 * noise_amp;

    // --- Apply TFT scanlines/grille last ---
    _scanline(col, uv);

    fragColor = vec4(col, 1.0);
}
