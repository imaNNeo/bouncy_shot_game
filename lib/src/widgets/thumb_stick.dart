import 'dart:math';

import 'package:flutter/material.dart';

class ThumbStick extends StatelessWidget {
  const ThumbStick({
    super.key,
    required this.size,
    required this.angle,
  });

  final double size;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // color: Colors.white,
              border: Border.fromBorderSide(
                BorderSide(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(4.0),
            child: Align(
              alignment: Alignment(
                cos(angle),
                sin(angle),
              ),
              child: Container(
                width: size / 4,
                height: size / 4,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}