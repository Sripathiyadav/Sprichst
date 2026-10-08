/// What the endpointer noticed about the sound it was fed.
enum Endpoint {
  /// Nothing to report.
  none,

  /// The learner has started talking.
  speechStarted,

  /// The learner talked and then stopped for long enough: their turn is over.
  speechEnded,

  /// Nobody said anything for the whole waiting time.
  noSpeech,
}

/// Decides when someone has finished speaking, from a stream of loudness
/// readings (dBFS, 0 is the loudest, about -160 is silence).
///
/// It is deliberately simple and testable: no audio, no clock, no timers. The
/// caller passes each reading with its timestamp.
///
/// * For the first [calibration] it measures the room's background level.
/// * Speech is sound clearly above that level ([marginDb]) that lasts at least
///   [minSpeech], so a door slam or a cough is not a turn.
/// * The turn ends after [endSilence] without speech. That pause is the main
///   comfort setting: too short cuts people off while they think; too long
///   makes the conversation feel slow.
class SpeechEndpointer {
  SpeechEndpointer({
    this.endSilence = const Duration(milliseconds: 1200),
    this.minSpeech = const Duration(milliseconds: 250),
    this.maxUtterance = const Duration(seconds: 30),
    this.noSpeechTimeout = const Duration(seconds: 12),
    this.calibration = const Duration(milliseconds: 400),
    this.marginDb = 12,
  });

  final Duration endSilence;
  final Duration minSpeech;
  final Duration maxUtterance;
  final Duration noSpeechTimeout;
  final Duration calibration;
  final double marginDb;

  /// Sound has to be at least this loud to count, however quiet the room is.
  static const minThresholdDb = -50.0;

  /// A very noisy room cannot push the threshold above this.
  static const maxThresholdDb = -25.0;

  /// Calm-room loudness assumed until it has been measured.
  static const _defaultFloorDb = -60.0;
  static const _floorBounds = (-80.0, -40.0);

  Duration? _startedAt;
  var _calibrationSum = 0.0;
  var _calibrationCount = 0;
  var _floor = _defaultFloorDb;
  Duration? _aboveSince;
  Duration? _speechStartedAt;
  Duration? _lastLoud;
  var _done = false;
  var _lastLevel = -160.0;

  bool get isSpeaking => _speechStartedAt != null && !_done;
  bool get isDone => _done;

  /// The loudness a reading must exceed to count as speech.
  double get thresholdDb =>
      (_floor + marginDb).clamp(minThresholdDb, maxThresholdDb);

  /// How loud the latest reading was, 0 (background) to 1 (clearly speaking),
  /// for drawing a level meter.
  double get level {
    final span = (-10 - _floor).clamp(10.0, 100.0);
    return ((_lastLevel - _floor) / span).clamp(0.0, 1.0);
  }

  void reset() {
    _startedAt = null;
    _calibrationSum = 0;
    _calibrationCount = 0;
    _floor = _defaultFloorDb;
    _aboveSince = null;
    _speechStartedAt = null;
    _lastLoud = null;
    _done = false;
    _lastLevel = -160;
  }

  /// Feeds one loudness reading taken at time [at] (any consistent clock).
  Endpoint feed(double db, Duration at) {
    if (_done) return Endpoint.none;
    _startedAt ??= at;
    _lastLevel = db;
    final elapsed = at - _startedAt!;

    if (elapsed < calibration && _speechStartedAt == null) {
      _calibrationSum += db;
      _calibrationCount++;
      if (_calibrationCount > 0) {
        _floor = (_calibrationSum / _calibrationCount)
            .clamp(_floorBounds.$1, _floorBounds.$2);
      }
      return Endpoint.none;
    }

    final loud = db > thresholdDb;

    if (_speechStartedAt == null) {
      if (loud) {
        _aboveSince ??= at;
        if (at - _aboveSince! >= minSpeech) {
          _speechStartedAt = _aboveSince;
          _lastLoud = at;
          return Endpoint.speechStarted;
        }
      } else {
        _aboveSince = null;
        // Background drifts (a fan starts); follow it slowly.
        _floor =
            (_floor * .95 + db * .05).clamp(_floorBounds.$1, _floorBounds.$2);
      }
      if (elapsed >= noSpeechTimeout) {
        _done = true;
        return Endpoint.noSpeech;
      }
      return Endpoint.none;
    }

    // Speaking: a little lower than the start threshold keeps trailing
    // syllables from counting as silence.
    if (db > thresholdDb - 3) _lastLoud = at;
    if (at - _lastLoud! >= endSilence ||
        at - _speechStartedAt! >= maxUtterance) {
      _done = true;
      return Endpoint.speechEnded;
    }
    return Endpoint.none;
  }
}
