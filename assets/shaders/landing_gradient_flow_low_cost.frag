// Low-cost landing gradient flow.
// Inspired by https://www.shadertoy.com/view/wdyczG, simplified for short-lived
// loading backgrounds: no procedural noise and only one sine warp.
#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform vec3 colorPrimary;
uniform vec3 colorSecondary;
uniform vec3 colorAccent1;
uniform vec3 colorAccent2;

out vec4 fragColor;

#define S(a,b,t) smoothstep(a,b,t)

mat2 Rot(float a) {
  float s = sin(a);
  float c = cos(a);
  return mat2(c, -s, s, c);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / iResolution.xy;
  float ratio = iResolution.x / iResolution.y;
  vec2 tuv = uv - 0.5;

  // Cheap deterministic drift: replaces the original per-pixel noise rotation.
  float angle = sin(iTime * 0.18) * 0.35 + 3.14159;

  tuv.y *= 1.0 / ratio;
  tuv *= Rot(angle);
  tuv.y *= ratio;

  // One soft wave instead of two cross-dependent warps.
  float frequency = 3.0;
  float amplitude = 45.0;
  float speed = iTime * 1.2;
  tuv.x += sin(tuv.y * frequency + speed) / amplitude;

  // Compute the gradient axis once and reuse it for both layers.
  vec2 gradUv = tuv * Rot(radians(-5.0));

  vec3 layer1 = mix(
    colorPrimary,
    colorSecondary,
    S(-0.3, 0.2, gradUv.x)
  );
  vec3 layer2 = mix(
    colorAccent1,
    colorAccent2,
    S(-0.3, 0.2, gradUv.x)
  );
  vec3 col = mix(layer1, layer2, S(0.5, -0.3, tuv.y));

  fragColor = vec4(col, 1.0);
}
