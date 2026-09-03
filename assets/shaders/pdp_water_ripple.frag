#version 460 core
precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution;
uniform vec2 origin;
uniform float time;
uniform float intensity;
uniform sampler2D image;

out vec4 fragColor;

const float amplitude = 0.030;
const float frequency = 18.0;
const float decay = 2.8;
const float speed = 0.78;

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 uv = fragCoord / iResolution;
  vec2 rippleOrigin = clamp(origin, vec2(0.0), vec2(1.0));

  vec2 delta = uv - rippleOrigin;
  float dist = length(delta);
  float delayedTime = max(0.0, time - (dist / speed));
  float wave = sin(frequency * delayedTime) * exp(-decay * delayedTime);
  float reveal = smoothstep(0.0, 0.08, delayedTime);
  float rippleSignal = intensity * wave * reveal;
  float rippleAmount = amplitude * rippleSignal;

  vec2 direction = normalize(delta + vec2(0.0001));
  vec2 displacedUv = uv + rippleAmount * direction;
  vec3 color = texture(image, displacedUv).rgb;
  color += 0.10 * rippleSignal;

  fragColor = vec4(color, 1.0);
}
