// Render an SVG to a transparent PNG (AppKit draws SVG natively). Usage: svg2png.js in.svg out.png size [inset]
// inset = fraction of empty margin on each side (macOS app icons use ~0.1: a 824 px body in 1024).
ObjC.import('AppKit');
function run(argv) {
  const [src, out, sizeStr, insetStr] = argv, size = parseInt(sizeStr, 10), pad = Math.round(size * (parseFloat(insetStr) || 0));
  const img = $.NSImage.alloc.initWithContentsOfFile(src);
  if (!img || img.isNil()) return 'cannot read ' + src;
  const rep = $.NSBitmapImageRep.alloc.initWithBitmapDataPlanesPixelsWidePixelsHighBitsPerSampleSamplesPerPixelHasAlphaIsPlanarColorSpaceNameBytesPerRowBitsPerPixel(
    null, size, size, 8, 4, true, false, $.NSDeviceRGBColorSpace, 0, 0);
  $.NSGraphicsContext.saveGraphicsState;
  $.NSGraphicsContext.setCurrentContext($.NSGraphicsContext.graphicsContextWithBitmapImageRep(rep));
  img.drawInRectFromRectOperationFraction($.NSMakeRect(pad, pad, size - 2 * pad, size - 2 * pad), $.NSZeroRect, $.NSCompositingOperationSourceOver, 1.0);
  $.NSGraphicsContext.restoreGraphicsState;
  const data = rep.representationUsingTypeProperties($.NSBitmapImageFileTypePNG, $({}));
  data.writeToFileAtomically(out, true);
  return 'ok';
}
