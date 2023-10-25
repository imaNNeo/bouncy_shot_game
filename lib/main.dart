import 'dart:math' hide Rectangle;

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/experimental.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame_forge2d/flame_forge2d.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(GameWidget(game: MyGame()));
}

class DraggingInfo {
  Vector2 startPosition;
  Vector2 currentPosition;

  double get length => (startPosition - currentPosition).length;

  bool get isNan => startPosition.isNaN || currentPosition.isNaN;

  Vector2 get direction => (startPosition - currentPosition).normalized();

  DraggingInfo(this.startPosition, this.currentPosition);
}

class MyGame extends Forge2DGame with DragCallbacks {
  MyGame() : super(gravity: Vector2.zero());
  static const availableColors = [
    Colors.red,
    Colors.greenAccent,
    Colors.lightGreenAccent,
    Colors.blueAccent,
    Colors.lightBlueAccent,
    Colors.purple,
    Colors.cyanAccent,
    Colors.deepPurpleAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.pink,
  ];

  static const playerKey = 'playerKey';
  DraggingInfo? dragging;

  late Player currentPlayer;
  late List<Player> bots;

  Rect get gameRect => const Rect.fromLTWH(0, 0, 100, 100);

  @override
  void onLoad() async {
    currentPlayer = Player(
      key: ComponentKey.named(playerKey),
      initialPosition: gameRect.center.toVector2(),
      color: Colors.white,
    );
    world.addAll(bots = List.generate(
      10,
      (index) => Player(
        initialPosition: gameRect.deflate(10).randomPoint(),
        color: availableColors.random(),
      ),
    ));
    await world.add(currentPlayer);
    await world.add(AimLine());
    final topLeft = gameRect.topLeft.toVector2();
    final topRight = gameRect.topRight.toVector2();
    final bottomRight = gameRect.bottomRight.toVector2();
    final bottomLeft = gameRect.bottomLeft.toVector2();
    await world.addAll([
      Wall(topLeft, topRight),
      Wall(topRight, bottomRight),
      Wall(bottomLeft, bottomRight),
      Wall(topLeft, bottomLeft),
    ]);
    camera.follow(currentPlayer, maxSpeed: 100, snap: true);
    super.onLoad();
  }

  @override
  void onDragStart(DragStartEvent event) {
    dragging = DraggingInfo(
      event.localPosition,
      event.localPosition,
    );
    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    dragging!.currentPosition = event.localPosition;
    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    currentPlayer.body.applyLinearImpulse(
      -dragging!.direction * dragging!.length * 1000,
    );
    dragging = null;
    super.onDragEnd(event);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    dragging = null;
    super.onDragCancel(event);
  }
}

class AimLine extends PositionComponent with HasGameRef<MyGame> {
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    const maxLength = 10.0;
    final dragging = game.dragging;
    if (dragging != null && !dragging.isNan) {
      final direction = dragging.direction;
      final angle = -atan2(direction.x, direction.y) + pi / 2;
      final length = dragging.length / 10;

      final ballOffset = game.currentPlayer.position.toOffset();
      canvas.drawLine(
        ballOffset,
        ballOffset + Offset(cos(angle), sin(angle)) * min(length, maxLength),
        Paint()
          ..color = Colors.lightGreenAccent
          ..strokeWidth = 0.2,
      );
    }
  }
}

class Player extends BodyComponent with TapCallbacks {
  Player({
    Vector2? initialPosition,
    super.key,
    this.radius = 3,
    required this.color,
  }) : super(
          fixtureDefs: [
            FixtureDef(
              CircleShape()..radius = radius,
              restitution: 0.8,
              density: 10.0,
              friction: 0.5,
            ),
          ],
          bodyDef: BodyDef(
            angularDamping: 0.8,
            position: initialPosition ?? Vector2.zero(),
            type: BodyType.dynamic,
          ),
        );

  final double radius;
  final Color color;

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    canvas.drawCircle(
      Offset.zero,
      3,
      Paint()..color = color,
    );
  }
}

class Wall extends BodyComponent {
  final Vector2 _start;
  final Vector2 _end;

  Wall(this._start, this._end);

  @override
  Body createBody() {
    final shape = EdgeShape()..set(_start, _end);
    final fixtureDef = FixtureDef(
      shape,
      friction: 0.3,
    );
    final bodyDef = BodyDef(
      position: Vector2.zero(),
      type: BodyType.static,
    );

    return world.createBody(bodyDef)..createFixture(fixtureDef);
  }
}
