import 'package:flutter_tts/flutter_tts.dart';

/// Real-time spoken route guidance for blind and low-vision travellers.
///
/// Wraps the platform text-to-speech engine so every navigation step is
/// announced as it becomes the "next step" — the step-by-step voice
/// instructions in the mapOKU pitch. Calls are best-effort: a missing or busy
/// speech engine never breaks navigation, it just stays silent.
class VoiceGuide {
  VoiceGuide._();

  static final VoiceGuide instance = VoiceGuide._();

  FlutterTts? _tts;
  bool _enabled = true;

  bool get enabled => _enabled;

  void setEnabled(bool value) {
    _enabled = value;
    if (!value) stop();
  }

  Future<FlutterTts> _engine() async {
    final existing = _tts;
    if (existing != null) return existing;

    final tts = FlutterTts();
    try {
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.48);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.awaitSpeakCompletion(true);
    } catch (_) {
      // Engine unavailable (desktop / web): speak() will simply no-op.
    }
    _tts = tts;
    return tts;
  }

  /// Speaks [text] straight away, replacing anything still playing so each
  /// navigation step supersedes the previous one.
  Future<void> speak(String text) async {
    if (!_enabled || text.trim().isEmpty) return;
    try {
      final tts = await _engine();
      await tts.stop();
      await tts.speak(text);
    } catch (_) {
      // Voice guidance is best-effort.
    }
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {
      // Ignore.
    }
  }
}
