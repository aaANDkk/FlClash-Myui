#version 460 core

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uResolution;
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

float gradientNoise(vec2 uv) {
    return fract(52.9829189 * fract(dot(uv, vec2(0.06711056, 0.00583715))));
}

vec4 accumPoint(vec4 color, vec4 pointColor, vec2 pointAnim, float rad, vec2 uv) {
    pointColor.rgb *= pointColor.a;
    float d = distance(uv, pointAnim);
    float pct = smoothstep(rad, 0.0, d);
    color.rgb = mix(color.rgb, pointColor.rgb, pct);
    color.a = mix(color.a, pointColor.a, pct);
    return color;
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 res = max(uResolution, vec2(1.0));
    vec2 vUv = fragCoord / res;
    vUv.y = 1.0 - vUv.y;
    vec2 uv = vUv;
    uv -= vec2(0.0, uTranslateY);
    uv.xy -= uBound.xy;
    uv.xy /= max(uBound.zw, vec2(0.0001));

    vec4 color = vec4(0.0);
    float noiseValue = perlin(vUv * uNoiseScale + vec2(-uAnimTime, -uAnimTime));

    color = accumPoint(color, uColor0, uPointAnim0, uPoint0.z * uPointRadiusMulti, uv);
    color = accumPoint(color, uColor1, uPointAnim1, uPoint1.z * uPointRadiusMulti, uv);
    color = accumPoint(color, uColor2, uPointAnim2, uPoint2.z * uPointRadiusMulti, uv);
    color = accumPoint(color, uColor3, uPointAnim3, uPoint3.z * uPointRadiusMulti, uv);

    float oppositeNoise = smoothstep(0.0, 1.0, noiseValue);
    color.rgb /= max(color.a, 0.0001);
    vec3 hsv = rgb2hsv(color.rgb);
    hsv.y = mix(hsv.y, 0.0, oppositeNoise * uSaturateOffset);
    color.rgb = hsv2rgb(hsv);
    color.rgb += oppositeNoise * uLightOffset;

    color.a = clamp(color.a, 0.0, 1.0);
    color.a *= uAlphaMulti;

    color += (10.0 / 255.0) * gradientNoise(fragCoord) - (5.0 / 255.0);
    color = clamp(color, 0.0, 1.0);
    fragColor = vec4(color.rgb * color.a, color.a);
}
