import { describe, it, expect } from '@ohos/hypium';
import { GameEngine } from '../main/ets/engine/GameEngine';
import { Difficulty, Direction, GameStatus } from '../main/ets/model/GameModels';

export default function localUnitTest() {
  describe('SnakeRushGameEngine', () => {
    it('startsWithFourSegments', 0, () => {
      const engine: GameEngine = new GameEngine(() => 0.5);
      const snapshot = engine.start(Difficulty.NORMAL);
      expect(snapshot.snake.length).assertEqual(4);
      expect(snapshot.score).assertEqual(0);
      expect(snapshot.status).assertEqual(GameStatus.RUNNING);
    });

    it('movesForwardOneCell', 0, () => {
      const engine: GameEngine = new GameEngine(() => 0.5);
      engine.start(Difficulty.NORMAL);
      const snapshot = engine.tick();
      expect(snapshot.snake[0].x).assertEqual(11);
      expect(snapshot.snake[0].y).assertEqual(10);
    });

    it('rejectsReverseDirection', 0, () => {
      const engine: GameEngine = new GameEngine(() => 0.5);
      engine.start(Difficulty.NORMAL);
      expect(engine.setDirection(Direction.LEFT)).assertFalse();
      const snapshot = engine.tick();
      expect(snapshot.snake[0].x).assertEqual(11);
    });

    it('pausesAndResumes', 0, () => {
      const engine: GameEngine = new GameEngine(() => 0.5);
      engine.start(Difficulty.NORMAL);
      expect(engine.pause().status).assertEqual(GameStatus.PAUSED);
      expect(engine.resume().status).assertEqual(GameStatus.RUNNING);
    });

    it('hitsWall', 0, () => {
      const engine: GameEngine = new GameEngine(() => 0.5);
      let snapshot = engine.start(Difficulty.HARD);
      for (let index = 0; index < 10; index += 1) {
        snapshot = engine.tick();
      }
      expect(snapshot.status).assertEqual(GameStatus.OVER);
    });
  });
}
