import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Teardrop pin with a letter, matching the web map's A / B / C markers.
class LetterPin extends StatelessWidget {
  const LetterPin({super.key, required this.letter, required this.color, this.size = 32});

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.white, width: 3),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(size / 2),
            topRight: Radius.circular(size / 2),
            bottomLeft: Radius.circular(size / 2),
            bottomRight: const Radius.circular(3),
          ),
          boxShadow: const [BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        alignment: Alignment.center,
        child: Transform.rotate(
          angle: -math.pi / 4,
          child: Text(
            letter,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

/// Reported obstacle on the map. 44 pt hit area around a 22 pt dot.
class ObstacleDot extends StatelessWidget {
  const ObstacleDot({super.key, this.dimmed = false});

  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: dimmed ? Palette.amber.withValues(alpha: 0.55) : Palette.amber,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 4, offset: Offset(0, 1))],
          ),
          child: const Icon(CupertinoIcons.exclamationmark, size: 12, color: Colors.white),
        ),
      ),
    );
  }
}

/// "You are here": blue would read as Apple Maps, so it's ink with a soft halo.
class YouAreHere extends StatelessWidget {
  const YouAreHere({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(color: Palette.ink.withValues(alpha: 0.14), shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Palette.ink,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
        ),
      ),
    );
  }
}
