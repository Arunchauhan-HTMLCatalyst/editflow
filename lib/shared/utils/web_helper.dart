import 'web_helper_stub.dart'
    if (dart.library.js) 'web_helper_web.dart' as loader;

void downloadFileWeb({
  required String base64Data,
  required String fileName,
  required String mimeType,
}) {
  loader.downloadFileWebImpl(
    base64Data: base64Data,
    fileName: fileName,
    mimeType: mimeType,
  );
}

bool isInAppBrowser() {
  return loader.isInAppBrowserImpl();
}

void registerIframe(String viewType, String url) {
  loader.registerIframeImpl(viewType, url);
}
