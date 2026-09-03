/// Rendering profile for the add-to-cart comet.
///
/// Native/desktop keeps the richer treatment. Web mobile uses a safer profile
/// permanently because CanvasKit/Chrome Android pays heavily for stacked
/// per-frame blurs. The first tap can be cheaper still while the real-surface
/// warm-up has not completed.
enum AddToCartCometRenderProfile { rich, webMobileSafe, webMobileFirstTapCheap }
