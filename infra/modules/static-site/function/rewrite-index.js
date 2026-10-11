// CloudFront Function (viewer-request, cloudfront-js-2.0).
//
// Astro's directory build format produces `/about/index.html`. S3 only serves
// a default document at the root, so map:
//   /about/   -> /about/index.html
//   /about    -> /about/index.html
// Paths whose last segment has an extension (e.g. /favicon.svg) pass through.
function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (uri.endsWith('/')) {
    request.uri = uri + 'index.html';
    return request;
  }

  var lastSegment = uri.substring(uri.lastIndexOf('/') + 1);
  if (!lastSegment.includes('.')) {
    request.uri = uri + '/index.html';
  }

  return request;
}
