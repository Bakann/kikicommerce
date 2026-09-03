#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

// Directional volumetric glow / light-scattering ("god rays") fragment shader.
// Adapted for this codebase (FlutterFragCoord, logical resolution) from the
// "Let it Glow!" pen by Selman Ay (https://codepen.io/selmancom/pen/yLVmEqY).
//
// The light source sits at (sourceX, sourceY). The host either slides it with
// the scroll or sweeps it horizontally across the glyphs (a focused point that
// illuminates each letter in turn). The scattered light is tinted with a core
// colour near the source fading to a falloff colour with distance.

uniform float width; // logical canvas width
uniform float height; // logical canvas height
uniform float sourceX; // light source X (0..1 across the canvas)
uniform float sourceY; // light source Y (0..1 down the canvas)
uniform float density; // spread of the scattering march
uniform float lightStrength; // falloff radius of the light
uniform float weight; // contribution of each scattering sample
uniform float lightR; // core tint, red
uniform float lightG; // core tint, green
uniform float lightB; // core tint, blue
uniform float falloffR; // distant tint, red
uniform float falloffG; // distant tint, green
uniform float falloffB; // distant tint, blue
uniform float falloff; // how fast the tint shifts from core to falloff
uniform float glowStrength; // multiplier on the scattered coverage (alpha)

uniform sampler2D tInput; // the snapshotted child (bright glyphs)
uniform sampler2D tNoise; // tiling noise for dithering

out vec4 fragColor;

const int samples = 16;
const float decay = 0.92;
const float baseExposure = 0.9;

float random2d(vec2 uv) {
  uv /= 256.0;
  vec4 tex = texture(tNoise, uv);
  return mix(tex.r, tex.g, tex.a);
}

float random(vec3 xyz) {
  return fract(sin(dot(xyz, vec3(12.9898, 78.233, 151.7182))) * 43758.5453);
}

vec4 occlusion(vec2 uv, vec2 lightpos, vec4 objects) {
  return (1.0 - smoothstep(0.0, lightStrength, length(lightpos - uv))) * objects;
}

void main() {
  vec2 resolution = vec2(width, height);
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / resolution;
  vec2 lightSource = vec2(sourceX, sourceY);

  vec4 obj = texture(tInput, uv);
  vec4 map = occlusion(uv, lightSource, obj);

  float rnd = random(vec3(fragCoord, 1.0));
  float exposure = baseExposure + (sin(rnd) * 0.5 + 1.0) * 0.05;

  vec2 marchUv = uv;
  vec2 step = (marchUv - lightSource) * (1.0 / float(samples) * density);

  float illuminationDecay = 1.0;
  for (int i = 0; i < samples; i++) {
    marchUv -= step;
    float movement = rnd * 20.0 * float(i + 1);
    float dither =
        random2d(uv + mod(vec2(movement * sin(rnd * 0.5), -movement), 1000.0)) *
        2.0;
    vec4 steppedMap = occlusion(uv, lightSource, texture(tInput, marchUv + step * dither));
    steppedMap *= illuminationDecay * weight;
    illuminationDecay *= decay;
    map += steppedMap;
  }

  // Use the scattered light as a coverage field, tinted from the core colour
  // near the source to the falloff colour with distance. Premultiplied output
  // so it composites cleanly over whatever is behind the canvas.
  float lum = dot(map.rgb, vec3(0.2126, 0.7152, 0.0722));
  float dist = length(lightSource - uv);
  vec3 tint = mix(
    vec3(lightR, lightG, lightB),
    vec3(falloffR, falloffG, falloffB),
    clamp(dist * falloff, 0.0, 1.0));
  float coverage = clamp(lum * exposure * glowStrength, 0.0, 1.0);
  fragColor = vec4(tint * coverage, coverage);
}
