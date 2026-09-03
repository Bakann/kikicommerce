#version 460 core
precision highp float;

#include <flutter/runtime_effect.glsl>

// Things look cleaner without highlights, and in some ways I prefer it.
// However, it's less interesting... I think? :)
#define HIGHLIGHTS

uniform vec2 iResolution;
uniform sampler2D iChannel0;

out vec4 fragColor;

// Serves no other purpose than to save having to write this out all the time.
// I'm using this on a buffer texture, so no sRGB to linear operation needs to be
// performed. I'm also using (and prefer to use) aspect correct pixel
// coordinates, so it's necessary to stretch out the X values before retrieving
// them. It's also possible to stretch out the UV coordinates first, then use a
// stretched sample spread, which is faster... Yeah, it's confusing, but it
// doesn't matter, just so long as you have a method you're happy with. :)
vec4 tx(in vec2 p) {
  p *= vec2(iResolution.y / iResolution.x, 1);
  return texture(iChannel0, p + 0.5 / iResolution.y);
}

// Blur function. Pretty standard.
vec4 bTx(in vec2 p) {
  // Sample spread -- Measured in pixels.
  float px = 2.0;

  // Result.
  vec4 c = vec4(0);

  // Standard equally weighted 3x3 blur.
  for (int i = 0; i < 9; i++) {
    int row = i / 3;
    int column = i - row * 3;
    c += tx(p + (vec2(float(row), float(column)) - 1.0) * px / iResolution.y);
  }

  // Normalizing the return value.
  return c / 9.0;

  /*
  // NxN blur.
  const int N = 5;
  for(int i = 0; i<N*N; i++) c += tx(p + (vec2(i/N, i%N) - float(N - 1)/2.)*px/iResolution.y);
  return c/float(N*N);
  */
}

void mainImage(out vec4 color, in vec2 fragCoord) {
  // Aspect correct pixel coordinates.
  vec2 uv = fragCoord / iResolution.y;

  // A 3x3 blurred texture sample. The generated warped imagery contains a few
  // high frequency speckles, so blurred samples mitigate that somewhat.
  // Denoising would be better, but this will do.
  vec4 col = bTx(uv);
  //vec4 col = tx(uv); // Standard single sample.

#ifdef HIGHLIGHTS
  // Bump mapping via cheap, directional derivative-based highlighting.
  vec2 px = 4.0 / iResolution.yy; // Sample spread.
  vec4 col2 = bTx(uv - px); // Seperate sample.
  float b =
      max(dot(col2 - col, vec4(0.299, 0.587, 0.114, 0)), 0.0) / length(px);
  col += col2.yzxw * col2.yzxw * b / 12.0; // Add the colored highlights.
#endif

  // Toning down the lower half slightly.
  col = mix(col, col.zyxw, max(0.3 - uv.y, 0.0));

  // Rough gamma correction.
  color = sqrt(max(col, 0.0));
}

void main() {
  mainImage(fragColor, FlutterFragCoord().xy);
}
