import 'package:bouncy_shot_game/build_variables.dart';
import 'package:bouncy_shot_game/src/my_game.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

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
            )
        ],
      ),
    );
  }
}
