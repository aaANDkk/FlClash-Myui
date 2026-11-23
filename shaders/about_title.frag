#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
uniform vec2 uOffset;
uniform float uAnimTime;
uniform vec4 uBound;
uniform float uTranslateY;
uniform vec3 uPoint0;
uniform vec3 uPoint1;
uniform vec3 uPoint2;
uniform vec3 uPoint3;
uniform vec2 uPointAnim0;
uniform vec2 uPointAnim1;
uniform vec2 uPointAnim2;
uniform vec2 uPointAnim3;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform float uAlphaMulti;
uniform float uNoiseScale;
uniform float uPointRadiusMulti;
uniform float uSaturateOffset;
uniform float uLightOffset;
uniform vec4 uSurface;
uniform float uIsDark;

out vec4 fragColor;

vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float hash(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.13);
    p3 += dot(p3, p3.yzx + 3.333);
    return fract((p3.x + p3.y) * p3.z);
}

float perlin(vec2 x) {
    vec2 i = floor(x);
    vec2 f = fract(x);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(a, b, u.x) + (c - a) * u.y * (1.0 - u.x) + (d - b) * u.x * u.y;
}

vec4 accumPoint(vec4 color, vec4 pointColor, vec2 pointAnim, float rad, vec2 uv) {
    pointColor.rgb *= pointColor.a;
    float d = distance(uv, pointAnim);
    float pct = smoothstep(rad, 0.0, d);
    color.rgb = mix(color.rgb, pointColor.rgb, pct);
    color.a = mix(color.a, pointColor.a, pct);
    return color;
}

vec3 sampleBlurredMesh(vec2 fragCoord) {
    vec2 res = max(uResolution, vec2(1.0));
    vec2 vUv = fragCoord / res;
    vUv.y = 1.0 - vUv.y;
    vec2 uv = (vUv - vec2(0.0, uTranslateY) - uBound.xy) / max(uBound.zw, vec2(0.0001));

    // Blur radius widening matching 150f textureBlur on the gradient backdrop.
    float blurWiden = uPointRadiusMulti * 1.45;
    vec4 color = vec4(0.0);
    color = accumPoint(color, uColor0, uPointAnim0, uPoint0.z * blurWiden, uv);
    color = accumPoint(color, uColor1, uPointAnim1, uPoint1.z * blurWiden, uv);
    color = accumPoint(color, uColor2, uPointAnim2, uPoint2.z * blurWiden, uv);
    color = accumPoint(color, uColor3, uPointAnim3, uPoint3.z * blurWiden, uv);

    float noiseValue = perlin(vUv * uNoiseScale + vec2(-uAnimTime, -uAnimTime));
    float oppositeNoise = smoothstep(0.0, 1.0, noiseValue) * 0.5;
    color.rgb /= max(color.a, 0.0001);
    vec3 hsv = rgb2hsv(color.rgb);
    hsv.y = mix(hsv.y, 0.0, oppositeNoise * uSaturateOffset);
    color.rgb = hsv2rgb(hsv);
    color.rgb += oppositeNoise * uLightOffset;

    float a = clamp(color.a, 0.0, 1.0);
    return mix(uSurface.rgb, clamp(color.rgb, 0.0, 1.0), a);
}

// Color Burn & Color Dodge (from Miuix Shaders.kt)
float blendColorBurnCh(float base, float blend) {
    return (blend == 0.0) ? blend : max(1.0 - ((1.0 - base) / blend), 0.0);
}
vec3 blendColorBurn(vec3 base, vec3 blend, float opacity) {
    vec3 res = vec3(
        blendColorBurnCh(base.r, blend.r),
        blendColorBurnCh(base.g, blend.g),
        blendColorBurnCh(base.b, blend.b)
    );
    return res * opacity + base * (1.0 - opacity);
}

float blendColorDodgeCh(float base, float blend) {
    return (blend == 1.0) ? blend : min(base / (1.0 - blend), 1.0);
}
vec3 blendColorDodge(vec3 base, vec3 blend, float opacity) {
    vec3 res = vec3(
        blendColorDodgeCh(base.r, blend.r),
        blendColorDodgeCh(base.g, blend.g),
        blendColorDodgeCh(base.b, blend.b)
    );
    return res * opacity + base * (1.0 - opacity);
}

float blendLinearLightCh(float base, float blend) {
    return blend < 0.5 ? max(base + 2.0 * blend - 1.0, 0.0) : min(base + 2.0 * (blend - 0.5), 1.0);
}
vec3 blendLinearLight(vec3 base, vec3 blend, float opacity) {
    vec3 res = vec3(
        blendLinearLightCh(base.r, blend.r),
        blendLinearLightCh(base.g, blend.g),
        blendLinearLightCh(base.b, blend.b)
    );
    return res * opacity + base * (1.0 - opacity);
}

// sRGB <-> XYZ <-> Lab (D65) matching Miuix Shaders.kt
vec3 rgb2xyz(vec3 c) {
    c.r = c.r > 0.04045 ? pow((c.r + 0.055) / 1.055, 2.4) : c.r / 12.92;
    c.g = c.g > 0.04045 ? pow((c.g + 0.055) / 1.055, 2.4) : c.g / 12.92;
    c.b = c.b > 0.04045 ? pow((c.b + 0.055) / 1.055, 2.4) : c.b / 12.92;
    c *= 100.0;
    return vec3(
        c.r * 0.4124 + c.g * 0.3576 + c.b * 0.1805,
        c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722,
        c.r * 0.0193 + c.g * 0.1192 + c.b * 0.9505
    );
}

vec3 xyz2lab(vec3 c) {
    vec3 w = vec3(95.047, 100.0, 108.883);
    c /= w;
    c.x = c.x > 0.008856 ? pow(c.x, 1.0 / 3.0) : 7.787 * c.x + 16.0 / 116.0;
    c.y = c.y > 0.008856 ? pow(c.y, 1.0 / 3.0) : 7.787 * c.y + 16.0 / 116.0;
    c.z = c.z > 0.008856 ? pow(c.z, 1.0 / 3.0) : 7.787 * c.z + 16.0 / 116.0;
    return vec3(116.0 * c.y - 16.0, 500.0 * (c.x - c.y), 200.0 * (c.y - c.z));
}

vec3 lab2xyz(vec3 lab) {
    float y = (lab.x + 16.0) / 116.0;
    float x = lab.y / 500.0 + y;
    float z = y - lab.z / 200.0;
    float y3 = y * y * y;
    float x3 = x * x * x;
    float z3 = z * z * z;
    y = y3 > 0.008856 ? y3 : (y - 16.0 / 116.0) / 7.787;
    x = x3 > 0.008856 ? x3 : (x - 16.0 / 116.0) / 7.787;
    z = z3 > 0.008856 ? z3 : (z - 16.0 / 116.0) / 7.787;
    return vec3(x * 95.047, y * 100.0, z * 108.883);
}

vec3 xyz2rgb(vec3 xyz) {
    xyz /= 100.0;
    float r = xyz.x *  3.2406 + xyz.y * -1.5372 + xyz.z * -0.4986;
    float g = xyz.x * -0.9689 + xyz.y *  1.8758 + xyz.z *  0.0415;
    float b = xyz.x *  0.0557 + xyz.y * -0.2040 + xyz.z *  1.0570;
    r = r > 0.0031308 ? 1.055 * pow(max(r, 0.0), 1.0 / 2.4) - 0.055 : 12.92 * r;
    g = g > 0.0031308 ? 1.055 * pow(max(g, 0.0), 1.0 / 2.4) - 0.055 : 12.92 * g;
    b = b > 0.0031308 ? 1.055 * pow(max(b, 0.0), 1.0 / 2.4) - 0.055 : 12.92 * b;
    return clamp(vec3(r, g, b), 0.0, 1.0);
}

// Color mapping in Lab space matching BlurBlendMode.Lab (mode 106 in Miuix Shaders.kt):
// rescales L* into [m*100, n*100] while preserving chromatic hue & saturation.
vec3 labColor(vec3 c, float m, float n) {
    vec3 lab = xyz2lab(rgb2xyz(clamp(c, 0.0, 1.0)));
    lab.r = (n - m) * lab.r + m * 100.0;
    return xyz2rgb(lab2xyz(lab));
}

void main() {
    vec2 coord = FlutterFragCoord().xy + uOffset;
    // Average a 5-point wide kernel across the gradient to reproduce the soft 150f blur sweep.
    vec3 bg = sampleBlurredMesh(coord) * 0.4
        + sampleBlurredMesh(coord + vec2(-36.0, -24.0)) * 0.15
        + sampleBlurredMesh(coord + vec2( 36.0, -24.0)) * 0.15
        + sampleBlurredMesh(coord + vec2(-36.0,  24.0)) * 0.15
        + sampleBlurredMesh(coord + vec2( 36.0,  24.0)) * 0.15;

    if (uIsDark > 0.5) {
        bg = blendColorDodge(bg, vec3(0.63137), 0.90196);
        bg = blendLinearLight(bg, vec3(0.90196), 0.30196);
        bg = labColor(bg, 0.10196, 0.96078);
    } else {
        bg = blendColorBurn(bg, vec3(0.29020), 0.80000);
        bg = blendLinearLight(bg, vec3(0.30980), 1.00000);
        bg = labColor(bg, 0.10196, 0.94902);
    }

    float a = clamp(uAlphaMulti, 0.0, 1.0);
    fragColor = vec4(bg * a, a);
}
