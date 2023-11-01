import 'dart:math' hide Rectangle;

import 'package:bouncy_shot_game/my_game.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle, Timer;
import 'package:flutter/material.dart';

class WallBox extends BodyComponent<MyGame> {
  @override
  Body createBody() => world.createBody(BodyDef(userData: this))
    ..createFixture(
      FixtureDef(
        ChainShape()..createLoop(game.rect.toVertices()),
        restitution: 0.8,
      ),
    );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    renderBody = false;
    final paint = Paint()
      ..color = const Color(0xFF0b1224)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = game.rect;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF12192b));
    canvas.drawRect(rect, paint);
    final topRight = Offset(
      max(
        rect.left,
        rect.left + (rect.right - rect.left) * game.remain / MyGame.totalTime,
      ),
      rect.top,
    );
    canvas.drawLine(rect.topLeft, topRight, paint..color = Colors.white);
  }
}
