#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

/*
"Magnifying glass" by Emmanuel Keller aka Tambako - August 2019
License Creative Commons Attribution-NonCommercial-ShareAlike 3.0 Unported
License.

Flutter ImageFilter.shader adaptation for the Sport bottom nav. The original
Shadertoy raymarch splits the object into lens/rim/handle and refracts a paper
texture through the glass. Here the paper texture is replaced by the real
backdrop sampler, so the lens remains transparent and magnifies/distorts the
content under the nav.
*/

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform vec4 u_tint;
uniform float u_activity;

out vec4 fragColor;

const float PI = 3.14159265359;

float saturate(float x) {
  return clamp(x, 0.0, 1.0);
}

vec4 backdrop(vec2 uv) {
  uv = clamp(uv, vec2(0.0), vec2(1.0));
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return texture(u_texture, uv);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
  vec2 pa = p - a;
  vec2 ba = b - a;
  float h = saturate(dot(pa, ba) / dot(ba, ba));
  return length(pa - ba * h);
}

float fillMask(float sd, float aa) {
  return 1.0 - smoothstep(0.0, aa, sd);
}

float strokeMask(float sd, float halfWidth, float aa) {
  return 1.0 - smoothstep(halfWidth, halfWidth + aa, abs(sd));
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec3 metal(vec2 p, vec3 tint, float light, float activity) {
  vec3 silver = vec3(0.80, 0.83, 0.88);
  vec3 base = mix(tint * 0.50, silver, 0.68 + activity * 0.08);
  float key = saturate(dot(normalize(p + vec2(0.05, 0.02)), normalize(vec2(-0.7, -0.7))));
  vec3 cool = vec3(0.63, 0.80, 1.0) * pow(saturate(1.0 - key), 3.0) * 0.26;
  vec3 warm = vec3(1.0, 0.95, 0.82) * pow(key, 7.0) * (0.50 + activity * 0.22);
  return base * (0.68 + light * 0.36) + cool + warm;
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float scale = min(u_size.x, u_size.y);
  vec2 uv = frag / u_size;
  vec2 p = (frag - 0.5 * u_size) / scale;

  vec4 original = backdrop(uv);
  vec3 tint = max(u_tint.rgb, vec3(0.02));
  float activity = saturate(u_activity);

  vec2 lensCenter = vec2(0.0);
  float lensRadius = 0.285;
  float rimWidth = 0.027;
  float aa = 1.6 / scale;

  vec2 handleDir = normalize(vec2(1.0, 1.0));
  vec2 handleA = lensCenter + handleDir * 0.225;
  vec2 handleB = lensCenter + handleDir * 0.595;
  float handleSd = sdSegment(p, handleA, handleB) - 0.052;
  float connectorSd = length(p - (lensCenter + handleDir * 0.225)) - 0.070;

  vec2 local = p - lensCenter;
  float lensSd = length(local) - lensRadius;
  float r = length(local) / lensRadius;

  float lensCore = fillMask(lensSd + rimWidth * 1.15, aa * 2.0);
  float rim = strokeMask(lensSd, rimWidth, aa * 2.2);
  float handle = fillMask(handleSd, aa * 2.1);
  float connector = fillMask(connectorSd, aa * 1.8);

  // Spherical magnification/refraction, mirroring the original shader's lens:
  // sample closer to the lens center, then bend near the edge.
  float bulge = sqrt(max(0.0, 1.0 - r * r));
  float zoom = mix(1.76 + activity * 0.10, 1.20, smoothstep(0.62, 1.0, r));
  vec2 radial = local / max(length(local), 0.0001);
  vec2 refractedLocal = local / zoom;
  refractedLocal += radial * pow(saturate(r), 2.7) * 0.030;
  refractedLocal += vec2(-0.012, -0.018) * bulge;
  vec2 sampleFrag = 0.5 * u_size + (lensCenter + refractedLocal) * scale;
  vec4 magnified = backdrop(sampleFrag / u_size);

  // Paper/glass cues from the reference: pale transparent glass, fine surface
  // texture, edge caustic, and a strong diagonal highlight.
  float paperGrain = (hash21(floor(sampleFrag * 0.42)) - 0.5) * 0.030;
  vec3 lensColor = magnified.rgb + paperGrain;
  lensColor = mix(lensColor, vec3(0.91, 0.96, 0.92), 0.055);
  lensColor += vec3(0.28, 0.54, 0.78) * pow(1.0 - saturate(r), 1.9) * 0.045;

  float diagonal = abs(dot(local, normalize(vec2(-0.78, 0.62))) - 0.035);
  float glint = fillMask(diagonal - 0.010, aa * 3.0);
  glint *= smoothstep(0.96, 0.20, r) * (0.35 + activity * 0.20);
  float edgeGlint = rim * smoothstep(0.0, 0.75, dot(radial, normalize(vec2(-0.7, -0.6))));

  vec3 col = original.rgb;
  col = mix(col, lensColor, lensCore * 0.98);
  col += vec3(1.0, 0.98, 0.88) * glint;

  float light = saturate(dot(normalize(vec3(local * 1.55, bulge)), normalize(vec3(-0.65, -0.8, 1.4))) * 0.5 + 0.5);
  vec3 rimColor = metal(local + vec2(0.08, 0.06), tint, light, activity);
  rimColor += vec3(1.0) * edgeGlint * 0.32;

  vec2 handleLocal = p - mix(handleA, handleB, 0.55);
  float handleLight = saturate(dot(normalize(handleLocal + vec2(0.035, 0.20)), normalize(vec2(-0.55, -0.83))) * 0.5 + 0.5);
  vec3 handleColor = mix(vec3(0.035, 0.037, 0.041), tint * 0.62, 0.18);
  handleColor = handleColor * (0.62 + handleLight * 0.42);
  handleColor += vec3(0.42) * pow(handleLight, 6.0);

  float hardware = max(handle, connector);
  col = mix(col, handleColor, hardware);
  col = mix(col, rimColor, rim);

  // Soft cast shadow like the reference, but subtle enough to keep the nav
  // readable when the backdrop is light.
  float objectDistance = min(min(abs(lensSd) - rimWidth, handleSd), connectorSd);
  float shadow = (1.0 - smoothstep(0.0, 0.125, objectDistance)) * 0.22;
  shadow *= 1.0 - max(lensCore, max(rim, hardware));
  col = mix(col, col * 0.58, shadow);

  float alpha = saturate(max(lensCore * 0.98, max(rim, hardware)) + shadow * 0.45);
  fragColor = vec4(col * alpha, alpha);
}
