import 'dart:math';

import 'package:bouncy_shot_game/build_constants.dart';
import 'package:bouncy_shot_game/src/my_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'widgets/thumb_stick.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late MyGame _myGame;

  @override
  void initState() {
    _myGame = MyGame();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GameWidget(
            game: _myGame,
          ),
          if (BuildConstants.commitHash.isNotEmpty)
            Align(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(BuildConstants.commitHash),
              ),
              alignment: Alignment.bottomLeft,
            ),
          ValueListenableBuilder(
            valueListenable: _myGame.draggingInfo,
            builder: (context, t, child) {
              final thumbSize = 60.0;
              final start = _myGame.draggingInfo.value.start;
              final end = _myGame.draggingInfo.value.end;
              if (start == null) {
                return const SizedBox();
              }
              final diff = end! - start;
              return Positioned(
                left: start.dx - thumbSize / 2,
                top: start.dy - thumbSize / 2,
                child: ThumbStick(
                  size: thumbSize,
                  angle: -atan2(diff.dx, diff.dy) + pi / 2,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
