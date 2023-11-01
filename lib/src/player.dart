import 'dart:math' hide Rectangle;

import 'package:bouncy_shot_game/src/bullet.dart';
import 'package:bouncy_shot_game/src/my_game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/extensions.dart';
import 'package:flame/particles.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle, Timer;
import 'package:flame_noise/flame_noise.dart';
import 'package:flutter/material.dart';

class Player extends BodyComponent<MyGame> {
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
        Offset.zero + (Offset(cos(normalAngle), sin(normalAngle)) * 10.0),
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
