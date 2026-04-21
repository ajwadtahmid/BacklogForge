enum GameStatus { backlog, playing, completed }

extension GameStatusFromString on String {
  GameStatus get toGameStatus => GameStatus.values.firstWhere(
    (e) => e.name == this,
    orElse: () => GameStatus.backlog,
  );
}
