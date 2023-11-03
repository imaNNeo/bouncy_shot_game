import 'package:bouncy_shot_game/src/my_game.dart';
import 'package:bouncy_shot_game/src/player.dart';
import 'package:bouncy_shot_game/src/wallbox.dart';
import 'package:flame/extensions.dart';
import 'package:flame_forge2d/flame_forge2d.dart' hide Particle, Timer;
import 'package:flutter/material.dart';

class Bullet extends BodyComponent<MyGame> with ContactCallbacks {
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
