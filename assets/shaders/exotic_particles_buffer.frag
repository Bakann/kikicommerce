#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform float iTime;
uniform float iFrame;
uniform sampler2D iChannel0;

out vec4 fragColor;

// Start off with a function, warp it, and accumulate color along the way.
// This one is just a more mutated version of a simple sine warp function,
// of which there are plenty of examples on Shadertoy.
vec3 warp(vec2 u, float ph1, float ph2) {
  // Initializing the warped UV coordinates. This gives it a bit
  // of a worm hole quality. There are infinitly other mutations.
  vec2 v = u - log(1.0 / max(length(u), 0.001)) * vec2(-1, 1);

  // Scene color.
  vec3 col = vec3(0.0);

  // Number of iterations.
  const int n = 5;

  for (int i = 0; i < n; i++) {
    // Warp function.
    v = cos(v.y - vec2(0, 1.57)) * exp(sin(v.x + ph1) + cos(v.y + ph2));
    v -= u;

    // Color via IQ's cosine palatte and shading.
    vec3 d = (0.5 +
        0.45 * cos(vec3(i) / float(n) * 3.0 + vec3(0, 1, 2) * 1.5)) /
        max(length(v), 0.001);
    // Accumulation.
    col += d * d / 32.0;

    // Adding noise for that fake path traced look.
    // Also, to hide speckling in amongst noise. :)
    //col += fract(sin(u.xyy*.7 + u.yxx + dot(u + fract(iTime),
    //             vec2(113.97, 27.13)))*45758.5453)*.01 - .005;
  }

  return col;
}

void mainImage(out vec4 color, in vec2 fragCoord) {
  // Aspect correct UV coordinates.
  vec2 u = (fragCoord - iResolution.xy * 0.5) / iResolution.y * 2.0;

  // Angular offsets.
  float ph1 = iTime * 0.6;
  float ph2 = sin(iTime) * 0.25;

  // Adding two warp functions phase shifted by a certain amount was
  // Jolle's interesting addition. Just the one would work, but isn't
  // as interesting.
  vec3 col = warp(u, ph1, ph2) + warp(u, ph1, ph2 + 1.57);

  // Toning things down slightly.
  col = mix(col, col.zyx, 0.1);

  // Noise, for that fake path traced feel. :)
  //col.xyz += fract(sin(u.xyy*.7 + u.yxx + dot(u + fract(iTime),
  //                 vec2(113.97, 27.13)))*45758.5453)*.1 - .05;

  // Mix the previous frames in.
  vec4 preCol = texture(iChannel0, (fragCoord + vec2(0.5)) / iResolution.xy);
  float blend = (iFrame < 2.0) ? 1.0 : 0.25;
  col = mix(preCol.xyz, col, blend);

  // Clamp and add to Buffer A.
  color = vec4(clamp(col, 0.0, 1.0), 1);
}

void main() {
  mainImage(fragColor, FlutterFragCoord().xy);
}
