// This app only runs on the web, so the browser's own file picker and
// window API are used instead of extra packages (keeps `flutter pub get` fast).
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'upload_exception.dart';

class PickedFile {
  const PickedFile({
    required this.name,
    required this.extension,
    required this.bytes,
  });

  final String name;
  final String extension;
  final Uint8List bytes;
}

/// Opens the browser's file chooser. Returns null if the person cancels.
Future<PickedFile?> pickFile({required List<String> extensions}) {
  final completer = Completer<PickedFile?>();
  void finish(PickedFile? value) {
    if (!completer.isCompleted) completer.complete(value);
  }

  final input = html.FileUploadInputElement()
    ..accept = extensions.map((e) => '.$e').join(',');

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      finish(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      Uint8List? bytes;
      if (result is Uint8List) {
        bytes = result;
      } else if (result is ByteBuffer) {
        bytes = result.asUint8List();
      }
      if (bytes == null) {
        finish(null);
        return;
      }
      final dot = file.name.lastIndexOf('.');
      finish(
        PickedFile(
          name: file.name,
          extension: dot >= 0 ? file.name.substring(dot + 1).toLowerCase() : '',
          bytes: bytes,
        ),
      );
    });
    reader.onError.listen((_) => finish(null));
    reader.readAsArrayBuffer(file);
  });
  input.addEventListener('cancel', (_) => finish(null));
  input.click();
  return completer.future;
}

/// Opens a link in a new browser tab.
void openInNewTab(String url) {
  html.AnchorElement(href: url)
    ..target = '_blank'
    ..rel = 'noopener'
    ..click();
}

/// Sends [bytes] with a POST and reports progress while it uploads.
/// Used for files, so a slow connection shows a moving progress bar.
Future<void> uploadWithProgress({
  required String url,
  required Map<String, String> headers,
  required Uint8List bytes,
  required void Function(int sent, int total) onProgress,
}) {
  final completer = Completer<void>();
  void fail(String message) {
    if (!completer.isCompleted) completer.completeError(UploadException(message));
  }

  final request = html.HttpRequest();
  request.open('POST', url);
  headers.forEach(request.setRequestHeader);

  request.upload.onProgress.listen((event) {
    final total = event.total ?? bytes.length;
    onProgress(event.loaded ?? 0, total == 0 ? bytes.length : total);
  });
  request.onLoad.listen((_) {
    final status = request.status ?? 0;
    if (status >= 200 && status < 300) {
      onProgress(bytes.length, bytes.length);
      if (!completer.isCompleted) completer.complete();
    } else if (status == 413) {
      fail('That file is too large.');
    } else if (status == 401 || status == 403) {
      fail('You are not allowed to upload this file. Please sign in again.');
    } else {
      fail('The upload failed (error $status). Please try again.');
    }
  });
  request.onError.listen(
    (_) => fail('The connection dropped. Check your data and try again.'),
  );
  request.onTimeout.listen(
    (_) => fail('The upload took too long. Check your data and try again.'),
  );
  request.send(bytes);
  return completer.future;
}

Future<Uint8List?> _readBlob(html.Blob blob) {
  final completer = Completer<Uint8List?>();
  final reader = html.FileReader();
  reader.onLoadEnd.listen((_) {
    final result = reader.result;
    if (completer.isCompleted) return;
    if (result is Uint8List) {
      completer.complete(result);
    } else if (result is ByteBuffer) {
      completer.complete(result.asUint8List());
    } else {
      completer.complete(null);
    }
  });
  reader.onError.listen((_) {
    if (!completer.isCompleted) completer.complete(null);
  });
  reader.readAsArrayBuffer(blob);
  return completer.future;
}

/// Shrinks a photo in the browser before upload (saves the person's data).
/// With [square] the centre of the picture is cropped to a square.
Future<Uint8List> compressImage(
  Uint8List bytes, {
  int maxSide = 512,
  double quality = 0.85,
  bool square = false,
}) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
  try {
    final image = html.ImageElement(src: url);
    final loaded = Completer<bool>();
    image.onLoad.listen((_) {
      if (!loaded.isCompleted) loaded.complete(true);
    });
    image.onError.listen((_) {
      if (!loaded.isCompleted) loaded.complete(false);
    });
    if (!await loaded.future) {
      throw const UploadException('We could not read that picture.');
    }

    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width == 0 || height == 0) {
      throw const UploadException('We could not read that picture.');
    }

    final int cropX;
    final int cropY;
    final int cropW;
    final int cropH;
    if (square) {
      final side = width < height ? width : height;
      cropX = (width - side) ~/ 2;
      cropY = (height - side) ~/ 2;
      cropW = side;
      cropH = side;
    } else {
      cropX = 0;
      cropY = 0;
      cropW = width;
      cropH = height;
    }

    final longest = cropW > cropH ? cropW : cropH;
    final scale = longest > maxSide ? maxSide / longest : 1.0;
    final outW = (cropW * scale).round();
    final outH = (cropH * scale).round();

    final canvas = html.CanvasElement(width: outW, height: outH);
    canvas.context2D.drawImageScaledFromSource(
      image,
      cropX,
      cropY,
      cropW,
      cropH,
      0,
      0,
      outW,
      outH,
    );
    final blob = await canvas.toBlob('image/jpeg', quality);
    final result = await _readBlob(blob);
    if (result == null) {
      throw const UploadException('We could not prepare that picture.');
    }
    return result;
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
