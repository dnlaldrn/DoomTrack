import 'package:flutter/material.dart';

const kBreathingTotal = Duration(seconds: 60);

/// Label and circle scale (0.5–1.0) at [sec] into the exercise: 4s in, 4s hold, 6s out.
(String, double) breathPhase(double sec) {
  final t = sec % 14;
  if (t < 4) return ('Breathe in', 0.5 + 0.5 * t / 4);
  if (t < 8) return ('Hold', 1.0);
  return ('Breathe out', 1.0 - 0.5 * (t - 8) / 6);
}

class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});
  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: kBreathingTotal)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    })
    ..forward();

  void _finish() => Navigator.of(context).pushReplacementNamed('/activities');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final sec = _c.value * kBreathingTotal.inSeconds;
            final (label, scale) = breathPhase(sec);
            final left = kBreathingTotal.inSeconds - sec.floor();
            return Column(
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    width: 260 * scale,
                    height: 260 * scale,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primaryContainer),
                  ),
                ),
                const SizedBox(height: 32),
                Text(label, style: Theme.of(context).textTheme.headlineMedium, semanticsLabel: label),
                const SizedBox(height: 8),
                Text('$left s', style: Theme.of(context).textTheme.bodyLarge),
                const Spacer(),
                TextButton(onPressed: _finish, child: const Text('Skip')),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
