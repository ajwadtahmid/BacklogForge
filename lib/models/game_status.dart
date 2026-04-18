enum GameStatus { backlog, playing, completed }

extension GameStatusFromString on String {
  GameStatus get toGameStatus => GameStatus.values.byName(this);
}
