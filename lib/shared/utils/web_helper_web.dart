import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

void downloadFileWebImpl({
  required String base64Data,
  required String fileName,
  required String mimeType,
}) {
  js.context.callMethod('eval', [
    '''
    var link = document.createElement('a');
    link.href = 'data:$mimeType;base64,$base64Data';
    link.download = '$fileName';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    '''
  ]);
}

bool isInAppBrowserImpl() {
  try {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('instagram') ||
        ua.contains('fban') ||
        ua.contains('fbav') ||
        ua.contains('twitter') ||
        ua.contains('micromessenger') ||
        ua.contains('snapchat') ||
        ua.contains('gsa/') ||
        ua.contains('inapp');
  } catch (_) {
    return false;
  }
}

void registerIframeImpl(String viewType, String url) {
  ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
    return html.IFrameElement()
      ..src = url
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allowFullscreen = true;
  });
}
