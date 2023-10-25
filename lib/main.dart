import 'dart:math' hide Rectangle;

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flame_noise/flame_noise.dart';
import 'package:flutter/material.dart';

void main() => runApp(GameWidget(game: MyGame()));

final rnd = Random();

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
  Future<void> onLoad() async {
    await world.addAll(
      bots = List.generate(
        10,
        (index) => Player(
          key: ComponentKey.named('player_$index'),
          initialPosition: gameRect.deflate(10).randomPoint(),
          color: availableColors.random(),
        ),
      ),
    );
    await world.add(
      currentPlayer = Player(
        key: ComponentKey.named(playerKey),
        initialPosition: gameRect.center.toVector2(),
        color: Colors.white,
      ),
    );
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
    camera.viewport.position = gameRect.center.toVector2();
    camera.viewport.anchor = Anchor.center;
    super.onLoad();
  }

  @override
  void onDragStart(DragStartEvent event) {
    dragging = DraggingInfo(event.localPosition, event.localPosition);
    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    dragging!.currentPosition = event.localPosition;
    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (!dragging!.isNan) {
      currentPlayer.fireBullet(dragging!);
    }
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
    final dragging = game.dragging;
    if (dragging != null && !dragging.isNan) {
      final direction = dragging.direction;
      final angle = -atan2(direction.x, direction.y) + pi / 2;
      final length = dragging.length / 10;
      final ballOffset = game.currentPlayer.position.toOffset();
      canvas.drawLine(
        ballOffset,
        ballOffset + Offset(cos(angle), sin(angle)) * min(length, 10.0),
        Paint()
          ..color = Colors.lightGreenAccent
          ..strokeWidth = 0.2,
      );
    }
  }
}

class Player extends BodyComponent {
  Player({
    required this.initialPosition,
    required this.color,
    required this.key,
    this.radius = 3,
  }) : super(key: key);

  final ComponentKey key;
  final Vector2 initialPosition;
  final double radius;
  final Color color;

  @override
  Body createBody() => world.createBody(
        BodyDef(
          angularDamping: 0.8,
          position: initialPosition,
          type: BodyType.dynamic,
        ),
      )..createFixture(
          FixtureDef(
            CircleShape()..radius = radius,
            restitution: 0.8,
            density: 10.0,
            friction: 0.5,
            userData: this,
          ),
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()..color = color,
    );
  }

  Future<void> fireBullet(DraggingInfo dragging) async {
    body.applyLinearImpulse(-dragging.direction * dragging.length * 1000);
    final angle = atan2(dragging.direction.y, dragging.direction.x);
    const bulletRadius = 0.5;
    final speed = dragging.length / 100000;
    final bullet = Bullet(
      playerKey: key,
      initialPosition: position +
          (Vector2(cos(angle), sin(angle)) * (radius + bulletRadius)),
      radius: bulletRadius,
      color: color,
      initialLinearImpulse: dragging.direction * speed * 100000,
    );
    await world.add(bullet);
  }

  void kill() {
    removeFromParent();
    Vector2 randomVector2() => (Vector2.random(rnd) - Vector2.random(rnd)) * 99;
    world.add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 40,
          lifespan: 0.8,
          generator: (i) {
            return AcceleratedParticle(
              speed: randomVector2(),
              acceleration: randomVector2(),
              child: ComputedParticle(
                renderer: (canvas, particle) {
                  canvas.drawCircle(
                    Offset.zero,
                    (radius / 2) * (1 - particle.progress),
                    Paint()..color = color.withOpacity(1 - particle.progress),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
    game.camera.viewfinder.add(
      MoveEffect.by(
        Vector2(4, 4),
        PerlinNoiseEffectController(duration: 0.4, frequency: 400),
      ),
    );
  }
}

class Bullet extends BodyComponent with ContactCallbacks {
  Bullet({
    required this.playerKey,
    required this.initialPosition,
    required this.radius,
    required this.color,
    required this.initialLinearImpulse,
  });

  final ComponentKey playerKey;
  final Vector2 initialPosition;
  final Vector2 initialLinearImpulse;

  @override
  Body createBody() => world.createBody(
        BodyDef(
          angularDamping: 0.8,
          position: initialPosition,
          type: BodyType.dynamic,
          bullet: true,
          userData: this,
        ),
      )..createFixture(
          FixtureDef(
            CircleShape()..radius = radius,
            restitution: 0.8,
            density: 1.0,
            friction: 0.5,
            userData: this,
          ),
        );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    body.applyLinearImpulse(initialLinearImpulse);
  }

  final double radius;
  final Color color;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, radius, Paint()..color = color);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is Wall) {
      explode();
    } else if (other is Player) {
      if (other.key == playerKey) {
        return;
      }
      other.kill();
      explode();
    }
  }

  void explode() => removeFromParent();
}

class Wall extends BodyComponent {
  final Vector2 _start;
  final Vector2 _end;

  Wall(this._start, this._end);

  @override
  Body createBody() => world.createBody(BodyDef(userData: this))
    ..createFixture(FixtureDef(EdgeShape()..set(_start, _end)));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawLine(
      _start.toOffset(),
      _end.toOffset(),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.square,
    );
  }
}
