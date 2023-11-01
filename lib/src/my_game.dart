import 'dart:math' hide Rectangle;
import 'package:bouncy_shot_game/src/player.dart';
import 'package:bouncy_shot_game/src/wallbox.dart';
import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/extensions.dart';
import 'package:flame/rendering.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle, Timer;
import 'package:flutter/material.dart';

class MyGame extends Forge2DGame
    with DragCallbacks, HasTimeScale, HasDecorator {
  MyGame()
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

  Rect get rect => const Rect.fromLTWH(-50, -50, 100, 100).deflate(4);

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
    FlameAudio.audioCache.loadAll(['explosion.wav']);
    FlameAudio.bgm.initialize();
    FlameAudio.bgm.play('bg.mp3');
    await world.addAll([
      WallBox(),
      ...List.generate(
        20,
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
        textRenderer: TextPaint(
          style: const TextStyle(
            fontSize: 6,
            shadows: [Shadow(blurRadius: 8)],
            color: Colors.white,
          ),
        ),
      ),
    );
    super.onLoad();
  }

  static const double totalTime = 25.0;
  double remain = totalTime;

  @override
  void update(double dt) {
    super.update(dt);
    remain -= dt;
    if (remain <= 0 || world.children.length <= 3) {
      topText.position = rect.center.toVector2();
      topText.textRenderer = TextPaint(
        style: const TextStyle(
          fontSize: 36,
          shadows: [Shadow(blurRadius: 40)],
          color: Colors.white,
        ),
      );
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
