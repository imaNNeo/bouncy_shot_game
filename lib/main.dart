import 'dart:math' hide Rectangle;
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle;
import 'package:flame_noise/flame_noise.dart';
import 'package:flutter/material.dart';

void main() => runApp(GameWidget(game: MyGame()));

Rect get rect => const Rect.fromLTWH(-50, -50, 100, 100).deflate(4);

class DraggingInfo {
  Vector2 startPosition;
  Vector2 currentPosition;

  double get length => (startPosition - currentPosition).length;

  bool get isNan => startPosition.isNaN || currentPosition.isNaN;

  Vector2 get direction => (startPosition - currentPosition).normalized();

  DraggingInfo(this.startPosition, this.currentPosition);
}

class MyGame extends Forge2DGame with DragCallbacks {
  MyGame()
      : super(
          gravity: Vector2.zero(),
          cameraComponent: CameraComponent.withFixedResolution(
            width: 1000,
            height: 1000,
          ),
        );
  DraggingInfo? dragging;
  late Player currentPlayer;

  @override
  Future<void> onLoad() async {
    final data = await AssetsCache().readJson('data/data.json');
    final availableColors = (data['colors'] as List<dynamic>)
        .map((e) => Color(int.parse(e as String)))
        .toList();
    FlameAudio.bgm.initialize();
    // FlameAudio.bgm.play('bg.mp3');
    await world.addAll([
      ...List.generate(
        10,
        (index) => Player(
          key: ComponentKey.named('player_$index'),
          initPos: rect.deflate(10).randomPoint(),
          color: availableColors.toList().random(),
        ),
      ),
      currentPlayer = Player(
        key: ComponentKey.named('mainPlayerKey'),
        initPos: rect.center.toVector2(),
        color: Colors.white,
      ),
      Wall(),
      AimLine(),
    ]);
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
    required this.initPos,
    required this.color,
    required this.key,
    this.r = 3,
  }) : super(key: key);

  final ComponentKey key;
  final Vector2 initPos;
  final double r;
  final Color color;

  @override
  Body createBody() => world.createBody(
        BodyDef(
          angularDamping: 0.8,
          position: initPos,
          type: BodyType.dynamic,
        ),
      )..createFixture(
          FixtureDef(
            CircleShape()..radius = r,
            restitution: 0.8,
            density: 10.0,
            friction: 0.5,
            userData: this,
          ),
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, r, Paint()..color = color);
  }

  Future<void> fireBullet(DraggingInfo dragging) async {
    if (dragging.length < 50) {
      return;
    }
    body.applyLinearImpulse(-dragging.direction * dragging.length * 1000);
    final ang = atan2(dragging.direction.y, dragging.direction.x);
    const bulletR = 0.5;
    final speed = dragging.length / 100000;
    await world.add(
      Bullet(
        playerKey: key,
        initPos: position + (Vector2(cos(ang), sin(ang)) * (r + bulletR)),
        radius: bulletR,
        color: color,
        initLinearImpulse: dragging.direction * speed * 100000,
      ),
    );
  }

  void kill() {
    FlameAudio.play('explosion.wav');
    removeFromParent();
    Vector2 randomVector2() =>
        (Vector2.random(Random()) - Vector2.random(Random())) * 99;
    world.add(
      ParticleSystemComponent(
        position: position,
        particle: Particle.generate(
          count: 40,
          lifespan: 0.8,
          generator: (i) => AcceleratedParticle(
            speed: randomVector2(),
            acceleration: randomVector2(),
            child: ComputedParticle(
              renderer: (canvas, particle) => canvas.drawCircle(
                Offset.zero,
                (r / 2) * (1 - particle.progress),
                Paint()..color = color.withOpacity(1 - particle.progress),
              ),
            ),
          ),
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
    required this.initPos,
    required this.radius,
    required this.color,
    required this.initLinearImpulse,
  });

  final ComponentKey playerKey;
  final Vector2 initPos;
  final Vector2 initLinearImpulse;

  @override
  Body createBody() => world.createBody(
        BodyDef(
          angularDamping: 0.8,
          position: initPos,
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
    body.applyLinearImpulse(initLinearImpulse);
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
      removeFromParent();
    } else if (other is Player) {
      if (other.key == playerKey) {
        return;
      }
      other.kill();
      removeFromParent();
    }
  }
}

class Wall extends BodyComponent {
  @override
  Body createBody() => world.createBody(BodyDef(userData: this))
    ..createFixture(FixtureDef(ChainShape()..createLoop(rect.toVertices())));

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    renderBody = false;
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5
        ..strokeCap = StrokeCap.square,
    );
  }
}
