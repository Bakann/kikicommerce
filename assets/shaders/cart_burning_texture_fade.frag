#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

// Adapted from "Burning Texture Fade" by Krzysztof Kondrak @k_kondrak.
// Burned pixels become transparent instead of painting a procedural background,
// so the real empty cart page behind this sampled layer is revealed.

uniform vec2 iResolution;
uniform float progress;
uniform sampler2D image;

out vec4 fragColor;

float r(in vec2 p) {
  return fract(cos(p.x * 42.98 + p.y * 43.23) * 1127.53);
}

float n(in vec2 p) {
  vec2 fn = floor(p);
  vec2 sn = smoothstep(vec2(0.0), vec2(1.0), fract(p));

  float h1 = mix(r(fn), r(fn + vec2(1.0, 0.0)), sn.x);
  float h2 = mix(r(fn + vec2(0.0, 1.0)), r(fn + vec2(1.0)), sn.x);
  return mix(h1, h2, sn.y);
}

float noise(in vec2 p) {
  return n(p / 32.0) * 0.58 +
         n(p / 16.0) * 0.2 +
         n(p / 8.0) * 0.1 +
         n(p / 4.0) * 0.05 +
         n(p / 2.0) * 0.02 +
         n(p) * 0.0125;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / iResolution.xy;
  vec4 source = texture(image, uv);

  float t = mix(-0.18, 1.08, progress);
  float field = noise(p * 0.4);
  float burned = 1.0 - smoothstep(t - 0.1, t + 0.1, field);
  float edge = 1.0 - smoothstep(0.0, 0.045, abs(field - t));

  vec3 fire = 1.6 * noise(2000.0 * uv) * vec3(1.2, 0.5, 0.0);
  vec3 color = clamp(source.rgb + edge * fire, 0.0, 1.0);
  // The noisy burn can leave large white paper islands until the last tick.
  // Fade those remnants near the end so the empty cart behind is revealed
  // progressively instead of appearing on the cleanup frame.
  float tailFade = 1.0 - smoothstep(0.35, 0.75, progress);
  float alpha = source.a * max(1.0 - burned, edge * 0.95) * tailFade;

  fragColor = vec4(color, alpha);
}
