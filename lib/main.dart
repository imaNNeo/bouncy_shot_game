import 'dart:math' hide Rectangle;
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/game.dart';
import 'package:flame/particles.dart';
import 'package:flame/rendering.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle, Timer;
import 'package:flame_noise/flame_noise.dart';
import 'package:flutter/material.dart';

void main() => runApp(GameWidget(game: Game()));

Rect get rect => const Rect.fromLTWH(-50, -50, 100, 100).deflate(4);

class Game extends Forge2DGame with DragCallbacks, HasTimeScale, HasDecorator {
  Game()
      : super(
          gravity: Vector2.zero(),
          cameraComponent: CameraComponent.withFixedResolution(
            width: 1000,
            height: 1000,
          ),
        );
  Vector2? draggingPosStart;
  Vector2? draggingPos;
  late Player currentPlayer;

  Vector2? get _dragLine => draggingPos == null || draggingPos!.isNaN
      ? null
      : draggingPosStart! - draggingPos!;

  double? get dragAngle =>
      _dragLine == null ? null : -atan2(_dragLine!.x, _dragLine!.y) + pi / 2;

  late TextComponent topText;
  final double bulletR = 0.5;
  final double playerR = 3.0;

  @override
  Color backgroundColor() => const Color(0xFF030a1a);

  Future<Iterable<Color>> get playerColors => AssetsCache()
      .readJson('data/colors.json')
      .then((v) => (v['c'] as List).map((e) => Color(int.parse(e as String))));

  @override
  Future<void> onLoad() async {
    final colors = (await playerColors).toList();
    FlameAudio.bgm.initialize();
    // FlameAudio.bgm.play('bg.mp3');
    await world.addAll([
      WallBox(),
      ...List.generate(
        15,
        (index) => Player(
          initPos: rect.deflate(10).randomPoint(),
          color: colors.random(),
        ),
      ),
      // AimLine(),
      currentPlayer = Player(
        mainPlayer: true,
        initPos: rect.center.toVector2(),
        color: const Color(0xFFeeeeee),
      ),
    ]);
    camera.viewfinder.add(
      topText = TextComponent(
        text: '0',
        position: rect.topCenter.toVector2() + Vector2(0, 1),
        anchor: Anchor.topLeft,
        textRenderer: TextPaint(style: const TextStyle(fontSize: 6)),
      ),
    );
    super.onLoad();
  }

  static const double totalTime = 10.0;
  double remain = totalTime;

  @override
  void update(double dt) {
    super.update(dt);
    remain -= dt;
    if (remain <= 0 || world.children.length <= 3) {
      topText.position = rect.center.toVector2();
      topText.textRenderer = TextPaint(style: const TextStyle(fontSize: 36));
      topText.anchor = Anchor.center;
      decorator = PaintDecorator.grayscale();
      FlameAudio.bgm.stop();
      timeScale = 0.0;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    draggingPosStart = screenToWorld(event.localPosition);
    super.onDragStart(event);
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    draggingPos = screenToWorld(event.localPosition);
    super.onDragUpdate(event);
  }

  @override
  void onDragEnd(DragEndEvent event) {
    if (dragAngle != null && !dragAngle!.isNaN && timeScale == 1.0) {
      currentPlayer.fireBullet(dragAngle!);
    }
    draggingPos = null;
    super.onDragEnd(event);
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    draggingPos = null;
    super.onDragCancel(event);
  }
}

class Player extends BodyComponent<Game> {
  Player({
    required this.initPos,
    required this.color,
    this.mainPlayer = false,
  });

  final Vector2 initPos;
  final Color color;
  final bool mainPlayer;

  @override
  Body createBody() => world.createBody(
        BodyDef(
          angularDamping: 0.8,
          position: initPos,
          type: BodyType.dynamic,
        ),
      )..createFixture(
          FixtureDef(
            CircleShape()..radius = game.playerR,
            restitution: 0.7,
            density: 10.0,
            friction: 0.5,
            userData: this,
          ),
        );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.dragAngle != null && game.timeScale == 1.0 && mainPlayer) {
      final normalAngle = game.dragAngle! - angle;
      canvas.drawLine(
        Offset.zero,
        Offset.zero + (Offset(cos(normalAngle), sin(normalAngle)) * 20.0),
        Paint()
          ..color = const Color(0xffb409ba)
          ..strokeWidth = 0.5,
      );
    }
    canvas.drawCircle(Offset.zero, game.playerR, Paint()..color = color);
  }

  Future<void> fireBullet(double angle) async {
    final dragLine = Vector2(cos(angle), sin(angle));
    body.applyLinearImpulse(-dragLine.normalized() * 200000);
    await world.add(
      Bullet(
        initPos: position + (dragLine * (game.playerR + game.bulletR)),
        initLinearImpulse: dragLine.normalized() * 400000,
      ),
    );
  }

  void kill() {
    // FlameAudio.play('explosion.wav');
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
                (game.playerR / 2) * (1 - particle.progress),
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

class Bullet extends BodyComponent<Game> with ContactCallbacks {
  Bullet({
    required this.initPos,
    required this.initLinearImpulse,
  });

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
            CircleShape()..radius = game.bulletR,
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

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.drawCircle(Offset.zero, game.bulletR, Paint()..color = Colors.white);
  }

  @override
  void beginContact(Object other, Contact contact) {
    if (other is WallBox) {
      removeFromParent();
    } else if (other is Player && !other.mainPlayer) {
      other.kill();
      removeFromParent();
      game.topText.text = (int.parse(game.topText.text) + 1).toString();
    }
  }
}

class WallBox extends BodyComponent<Game> {
  @override
  Body createBody() => world.createBody(BodyDef(userData: this))
    ..createFixture(
      FixtureDef(ChainShape()..createLoop(rect.toVertices()), restitution: 0.8),
    );

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    renderBody = false;
    final paint = Paint()
      ..color = const Color(0xFF0b1224)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, Paint()..color = const Color(0xFF12192b));
    canvas.drawRect(rect, paint);
    final topRight = Offset(
      max(
        rect.left,
        rect.left + (rect.right - rect.left) * game.remain / Game.totalTime,
      ),
      rect.top,
    );
    canvas.drawLine(rect.topLeft, topRight, paint..color = Colors.white);
  }
}
