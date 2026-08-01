class GameManager {

  bool gameOver = false;

  void triggerGameOver() {
    gameOver = true;
  }

  void reset() {

    gameOver = false;

  }

}