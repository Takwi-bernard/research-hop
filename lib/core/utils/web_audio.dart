// Voice notes use the browser's own recorder and player, so no extra
// packages are needed.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import 'upload_exception.dart';

class RecordedAudio {
  const RecordedAudio({
    required this.bytes,
    required this.mimeType,
    required this.extension,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String mimeType;
  final String extension;
  final int durationMs;
}

/// Records from the microphone. Call [start], then [stop] (keeps the audio)
/// or [cancel] (throws it away).
class VoiceRecorder {
  html.MediaStream? _stream;
  html.MediaRecorder? _recorder;
  final List<html.Blob> _chunks = [];
  DateTime? _startedAt;
  String _mime = 'audio/webm';

  bool get recording => _recorder != null;

  Future<void> start() async {
    final devices = html.window.navigator.mediaDevices;
    if (devices == null) {
      throw const UploadException(
        'Voice notes are not supported in this browser.',
      );
    }
    try {
      _stream = await devices.getUserMedia({'audio': true});
    } catch (_) {
      throw const UploadException(
        'The microphone is blocked. Allow it in your browser and try again.',
      );
    }

    String? chosen;
    for (final candidate in const [
      'audio/webm;codecs=opus',
      'audio/webm',
      'audio/mp4',
    ]) {
      if (html.MediaRecorder.isTypeSupported(candidate)) {
        chosen = candidate;
        break;
      }
    }
    _mime = (chosen ?? 'audio/webm').split(';').first;

    final stream = _stream!;
    final recorder = chosen == null
        ? html.MediaRecorder(stream)
        : html.MediaRecorder(stream, {'mimeType': chosen});
    _chunks.clear();
    recorder.addEventListener('dataavailable', (event) {
      final blob = (event as html.BlobEvent).data;
      if (blob != null && blob.size > 0) _chunks.add(blob);
    });
    _recorder = recorder;
    _startedAt = DateTime.now();
    recorder.start();
  }

  void _release() {
    final stream = _stream;
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    _stream = null;
    _recorder = null;
  }

  Future<RecordedAudio?> stop() async {
    final recorder = _recorder;
    if (recorder == null) return null;
    final done = Completer<void>();
    recorder.addEventListener('stop', (_) {
      if (!done.isCompleted) done.complete();
    });
    final started = _startedAt ?? DateTime.now();
    try {
      recorder.stop();
    } catch (_) {
      _release();
      return null;
    }
    await done.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {},
    );
    _release();
    if (_chunks.isEmpty) return null;

    final blob = html.Blob(List<html.Blob>.of(_chunks), _mime);
    final reader = html.FileReader();
    final read = Completer<Uint8List?>();
    reader.onLoadEnd.listen((_) {
      final result = reader.result;
      if (read.isCompleted) return;
      if (result is Uint8List) {
        read.complete(result);
      } else if (result is ByteBuffer) {
        read.complete(result.asUint8List());
      } else {
        read.complete(null);
      }
    });
    reader.onError.listen((_) {
      if (!read.isCompleted) read.complete(null);
    });
    reader.readAsArrayBuffer(blob);
    final bytes = await read.future;
    if (bytes == null || bytes.isEmpty) return null;

    return RecordedAudio(
      bytes: bytes,
      mimeType: _mime,
      extension: _mime == 'audio/mp4' ? 'm4a' : 'webm',
      durationMs: DateTime.now().difference(started).inMilliseconds,
    );
  }

  void cancel() {
    final recorder = _recorder;
    if (recorder != null) {
      try {
        recorder.stop();
      } catch (_) {}
    }
    _chunks.clear();
    _release();
  }
}

/// Plays one audio address. Listen with [onChange] to redraw.
class WebAudioPlayer {
  WebAudioPlayer(String url) : _audio = html.AudioElement(url) {
    _audio.preload = 'auto';
    _audio.onPlay.listen((_) => _notify());
    _audio.onPause.listen((_) => _notify());
    _audio.onEnded.listen((_) => _notify());
    _audio.onTimeUpdate.listen((_) => _notify());
    _audio.onError.listen((_) {
      failed = true;
      _notify();
    });
  }

  final html.AudioElement _audio;
  void Function()? onChange;
  bool failed = false;

  void _notify() => onChange?.call();

  bool get playing => !_audio.paused && !_audio.ended;
  int get positionMs => (_audio.currentTime * 1000).round();

  Future<void> toggle() async {
    try {
      if (playing) {
        _audio.pause();
      } else {
        if (_audio.ended) _audio.currentTime = 0;
        await _audio.play();
      }
    } catch (_) {
      failed = true;
      _notify();
    }
  }

  void dispose() {
    onChange = null;
    _audio.pause();
    _audio.removeAttribute('src');
  }
}
