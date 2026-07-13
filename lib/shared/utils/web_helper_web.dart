import 'dart:js' as js;

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
