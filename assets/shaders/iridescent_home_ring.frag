#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform sampler2D iChannel0;

out vec4 fragColor;

float saturate(float x) {
  return clamp(x, 0.0, 1.0);
}

float hash21(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  vec2 p = frag - 0.5 * u_resolution.xy;

  float r = length(p);
  float outerRadius = 22.6;
  float innerRadius = 19.2;
  float edge = 0.7;
  float outerMask = 1.0 - smoothstep(outerRadius - edge, outerRadius, r);
  float centerMask = 1.0 - smoothstep(innerRadius - edge, innerRadius + edge, r);

  vec2 shaderUv = p / (outerRadius * 2.0) + 0.5;
  vec4 particleColor = texture(iChannel0, clamp(shaderUv, vec2(0.0), vec2(1.0)));

  float haloField = length(vec2(p.x * 0.78, p.y * 1.34));
  float haloMask = 1.0 - smoothstep(outerRadius * 0.82, 58.0, haloField);
  haloMask *= smoothstep(innerRadius * 0.78, outerRadius * 1.18, r);
  haloMask *= 0.42;
  vec2 haloUv = p / 116.0 + 0.5;
  vec3 haloColor = texture(iChannel0, clamp(haloUv, vec2(0.0), vec2(1.0))).rgb;
  haloColor = mix(haloColor, haloColor.gbr, 0.18);
  float haloLuma = dot(haloColor, vec3(0.299, 0.587, 0.114));
  haloColor = mix(vec3(haloLuma), haloColor, 1.75);
  haloColor = 1.0 - exp(-max(haloColor, vec3(0.0)) * 1.35);

  float lensR = r / innerRadius;
  float bulge = sqrt(max(0.0, 1.0 - lensR * lensR));
  vec2 lensDir = p / max(r, 0.001);
  float lensRim = smoothstep(0.62, 1.0, lensR);
  float zoom = mix(1.80, 1.18, lensRim);
  vec2 refracted = p / zoom;
  refracted += lensDir * pow(saturate(lensR), 2.7) * 1.75;
  refracted += vec2(-0.70, -1.05) * bulge;
  vec2 lensUv = refracted / (outerRadius * 2.0) + 0.5;
  vec2 chroma = lensDir * lensRim * 0.010;
  vec3 lensColor = vec3(
    texture(iChannel0, clamp(lensUv - chroma, vec2(0.0), vec2(1.0))).r,
    texture(iChannel0, clamp(lensUv, vec2(0.0), vec2(1.0))).g,
    texture(iChannel0, clamp(lensUv + chroma, vec2(0.0), vec2(1.0))).b
  );
  float grain = (hash21(floor((refracted + 0.5 * u_resolution.xy) * 0.42)) - 0.5) * 0.026;
  lensColor += grain;
  float lensLuma = dot(lensColor, vec3(0.299, 0.587, 0.114));
  lensColor = mix(vec3(lensLuma), lensColor, 1.45);
  lensColor = mix(lensColor, vec3(0.91, 0.96, 0.92), 0.045);
  lensColor += vec3(0.28, 0.54, 0.78) * pow(1.0 - saturate(lensR), 1.9) * 0.06;
  lensColor = mix(lensColor * 1.14, lensColor * 0.68, lensRim);
  float diagonal = abs(dot(p, normalize(vec2(-0.78, 0.62))) - 1.9);
  float glint = (1.0 - smoothstep(0.0, 1.9, diagonal)) * smoothstep(1.0, 0.22, lensR) * 0.34;
  float edgeGlint = lensRim * smoothstep(0.0, 0.75, dot(lensDir, normalize(vec2(-0.7, -0.6))));
  float lensHighlight = pow(1.0 - smoothstep(0.0, innerRadius * 0.78, length(p - vec2(-5.2, -5.9))), 2.2);
  lensColor += vec3(1.0, 0.98, 0.88) * glint;
  lensColor += vec3(0.76, 0.92, 1.0) * lensHighlight * 0.15;
  lensColor += vec3(0.62, 0.76, 1.0) * edgeGlint * 0.18;

  vec3 ringColor = particleColor.rgb * (1.12 + 0.16 * smoothstep(innerRadius, outerRadius, r));
  vec3 discColor = mix(ringColor, lensColor, centerMask);
  float alpha = max(outerMask, haloMask);
  vec3 col = discColor * outerMask + haloColor * haloMask;

  fragColor = vec4(col, alpha);
}

// Ring mask pass. The sampled iChannel0 image is the Shadertoy Exotic
// Particles Image tab rendered from its Buffer A feedback pass; the center is
// a magnifying lens over that same shader, and the low-alpha halo continues the
// same shader color onto the navbar.
