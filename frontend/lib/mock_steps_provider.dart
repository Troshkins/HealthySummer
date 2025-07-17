import 'dart:async';
import 'dart:math';

class MockStepsProvider {
  final void Function(int totalSteps) onStep;
  final Duration interval;
  final int maxStepIncrement;
  Timer? _timer;
  int _total = 0;
  int _tick = 0;

  MockStepsProvider({required this.onStep, this.interval = const Duration(seconds: 1), this.maxStepIncrement = 5});

  void start() {
    _timer = Timer.periodic(interval, (timer) {
      int inc;
      _tick++;
      if (Random().nextInt(30) == 0) {
        inc = Random().nextInt(31) + 20; // 20–50 steps burst
      } else {
        inc = Random().nextInt(maxStepIncrement + 1); // 0–maxStepIncrement
      }
      _total += inc;
      onStep(_total);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}