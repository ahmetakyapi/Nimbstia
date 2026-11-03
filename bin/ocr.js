// Recognize text in an image with the Vision framework (Turkish + English); prints lines.
ObjC.import('Foundation'); ObjC.import('Vision'); ObjC.import('AppKit');
function run(argv) {
  const img = $.NSImage.alloc.initWithContentsOfFile(argv[0]);
  if (!img || img.isNil()) return '';
  const rep = $.NSBitmapImageRep.imageRepWithData(img.TIFFRepresentation);
  const cg = rep.CGImage;
  const req = $.VNRecognizeTextRequest.alloc.init;
  req.recognitionLevel = 0; // accurate
  req.usesLanguageCorrection = true;
  req.recognitionLanguages = $(['tr-TR', 'en-US']);
  const h = $.VNImageRequestHandler.alloc.initWithCGImageOptions(cg, $({}));
  h.performRequestsError($([req]), null);
  const res = req.results, out = [];
  for (let i = 0; i < res.count; i++) {
    const c = res.objectAtIndex(i).topCandidates(1);
    if (c.count) out.push(c.objectAtIndex(0).string.js);
  }
  return out.join('\n');
}
