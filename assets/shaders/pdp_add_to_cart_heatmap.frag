#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

// Heatmap reveal for the PDP "add to cart" bar. Direct port of the Paper Design
// heatmap shader (https://github.com/paper-design/shaders): the shadowShape()
// soft forms sweep vertically (posY -1 -> 2) in three phase-shifted copies and
// carve a warm field, which is mapped through the cold->hot gradient so the bar
// reads like a heat camera. The logo-specific (Apple) masks are dropped and the
// shape is the whole bar; the white label/price keep a dark scrim halo.

uniform vec2 iResolution;
uniform float progress; // 0..1 over the effect lifetime (~2.4s), raw controller value
uniform sampler2D image; // live snapshot of the button

out vec4 fragColor;

#define TWO_PI 6.28318530718

// Paper heatmap palette, cold (#11206a) -> hot (#ff4c00).
vec3 heatColor(float x) {
  vec3 c0 = vec3(0.0667, 0.1255, 0.4157);
  vec3 c1 = vec3(0.1216, 0.2314, 0.6353);
  vec3 c2 = vec3(0.1843, 0.3882, 0.9059);
  vec3 c3 = vec3(0.4196, 0.8431, 1.0000);
  vec3 c4 = vec3(1.0000, 0.9020, 0.4745);
  vec3 c5 = vec3(1.0000, 0.6000, 0.1176);
  vec3 c6 = vec3(1.0000, 0.2980, 0.0000);
  x = clamp(x, 0.0, 1.0) * 6.0;
  vec3 col = c0;
  col = mix(col, c1, clamp(x - 0.0, 0.0, 1.0));
  col = mix(col, c2, clamp(x - 1.0, 0.0, 1.0));
  col = mix(col, c3, clamp(x - 2.0, 0.0, 1.0));
  col = mix(col, c4, clamp(x - 3.0, 0.0, 1.0));
  col = mix(col, c5, clamp(x - 4.0, 0.0, 1.0));
  col = mix(col, c6, clamp(x - 5.0, 0.0, 1.0));
  return col;
}

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453123);
}

// --- helpers from the original shader ---
float circle(vec2 uv, vec2 c, vec2 r) {
  return 1.0 - smoothstep(r[0], r[1], length(uv - c));
}

float lst(float edge0, float edge1, float x) {
  return clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
}

float sst(float edge0, float edge1, float x) {
  return smoothstep(edge0, edge1, x);
}

// Generic port of the original shadowShape(): the Apple-specific circles/leaf
// masks are removed, keeping the base form that sweeps vertically plus a couple
// of drifting side balls for variety.
float shadowShape(vec2 uv, float t) {
  vec2 scaledUV = uv;

  // Base form trajectory: posY travels from -1 to 2 as t goes 0 -> 1.
  float posY = mix(-1.0, 2.0, t);

  // Stretch the form as it sweeps through.
  scaledUV.y -= 0.5;
  float mainCircleScale = sst(0.0, 0.8, posY) * lst(1.4, 0.9, posY);
  scaledUV *= vec2(1.0, 1.0 + 1.5 * mainCircleScale);
  scaledUV.y += 0.5;

  float innerR = 0.4;
  float outerR = 1.0 - 0.3 * (sst(0.1, 0.2, t) * sst(0.5, 0.2, t));
  float s = circle(scaledUV, vec2(0.5, posY - 0.2), vec2(innerR, outerR));
  s = pow(s, 1.4);
  s *= 1.2;

  // Flat gradient that takes over the form near the top of its travel.
  {
    float pos = posY - uv.y;
    float edge = 1.2;
    float topFlattener = lst(-0.4, 0.0, pos) * sst(edge, 0.0, pos);
    topFlattener = pow(topFlattener, 3.0);
    float topFlattenerMixer = (1.0 - sst(0.0, 0.3, pos));
    s = mix(topFlattener, s, topFlattenerMixer);
  }

  // Drifting side balls (the original's "random balls"), for variety.
  {
    float pos = sst(0.0, 0.6, t) * sst(1.0, 0.6, t);
    s = mix(s, 0.5, circle(uv, vec2(0.0, 1.2 - 0.5 * pos), vec2(0.1, 0.3)));
    s = mix(s, 0.0, circle(uv, vec2(1.0, 0.5 + 0.5 * pos), vec2(0.1, 0.3)));
    s = mix(
      s,
      1.0,
      circle(uv, vec2(0.95, 0.2 + 0.2 * sst(0.3, 0.4, t) * sst(0.7, 0.5, t)),
        vec2(0.07, 0.22))
    );
  }

  return clamp(s, 0.0, 1.0);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / iResolution;
  vec4 original = texture(image, uv);

  // Flow time + in/out envelope derived from progress (no extra uniform).
  float dt = progress; // one sweep cycle over the effect lifetime
  float envIn = smoothstep(0.0, 0.12, progress);
  float envOut = 1.0 - smoothstep(0.80, 1.0, progress);
  float intensity = envIn * envOut; // 0 at the ends, 1 while it holds
  if (intensity <= 0.0) {
    fragColor = original;
    return;
  }

  // Three phase-shifted copies, exactly like the original, for a continuous
  // procession of forms sweeping through the bar.
  float t = mod(dt, 1.0);
  float tCopy = mod(dt + 1.0 / 3.0, 1.0);
  float tCopy2 = mod(dt + 2.0 / 3.0, 1.0);

  float shadow = shadowShape(uv, t);
  float shadowCopy = shadowShape(uv, tCopy);
  float shadowCopy2 = shadowShape(uv, tCopy2);

  // Warm baseline carved toward cold by the sweeping forms (original's inner).
  float inner = 0.85;
  inner = mix(inner, 0.0, shadow);
  inner = mix(inner, 0.0, shadowCopy);
  inner = mix(inner, 0.0, shadowCopy2);
  inner = clamp(inner, 0.0, 1.0);

  // Map to the heat gradient, with the original's faint grain.
  float heat = inner;
  heat += (hash(uv + floor(dt * 50.0)) - 0.5) * 0.05;
  heat = clamp(heat, 0.0, 1.0);
  vec3 thermal = heatColor(heat);

  // Fill the whole bar with the heatmap. The label/price now live in a separate
  // layer on top of this one, so nothing has to be masked out here (and the
  // text is never rasterised into this texture, which is what pixelated it).
  vec3 col = mix(original.rgb, thermal, intensity);

  fragColor = vec4(clamp(col, 0.0, 1.0), original.a);
}
