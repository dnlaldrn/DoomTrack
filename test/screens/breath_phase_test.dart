import 'package:doomtrack/screens/breathing_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('starts breathing in, small', () => expect(breathPhase(0), ('Breathe in', 0.5)));
  test('in grows to full at 4s', () => expect(breathPhase(4).$2, 1.0));
  test('hold 4–8s at full', () => expect(breathPhase(6), ('Hold', 1.0)));
  test('out 8–14s shrinks', () {
    expect(breathPhase(11), ('Breathe out', 0.75));
  });
  test('cycle repeats every 14s', () => expect(breathPhase(14 + 6), breathPhase(6)));
  test('total is 60s', () => expect(kBreathingTotal, const Duration(seconds: 60)));
}
