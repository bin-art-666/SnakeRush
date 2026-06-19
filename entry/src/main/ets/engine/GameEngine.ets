import {
  Difficulty,
  Direction,
  GameSnapshot,
  GameStatus,
  Point
} from '../model/GameModels';

export type RandomProvider = () => number;

export class GameEngine {
  static readonly BOARD_SIZE: number = 20;
  private snake: Point[] = [];
  private food: Point = new Point(14, 10);
  private direction: Direction = Direction.RIGHT;
  private queuedDirection: Direction | null = null;
  private score: number = 0;
  private bestScore: number = 0;
  private eatenCount: number = 0;
  private status: GameStatus = GameStatus.IDLE;
  private difficulty: Difficulty = Difficulty.NORMAL;
  private random: RandomProvider;

  constructor(random: RandomProvider = Math.random) {
    this.random = random;
  }

  start(difficulty: Difficulty, bestScore: number = 0): GameSnapshot {
    this.difficulty = difficulty;
    this.bestScore = bestScore;
    this.snake = [
      new Point(10, 10),
      new Point(9, 10),
      new Point(8, 10),
      new Point(7, 10)
    ];
    this.direction = Direction.RIGHT;
    this.queuedDirection = null;
    this.score = 0;
    this.eatenCount = 0;
    this.status = GameStatus.RUNNING;
    this.food = this.generateFood();
    return this.snapshot();
  }

  setDirection(next: Direction): boolean {
    if (this.status !== GameStatus.RUNNING || this.queuedDirection !== null) {
      return false;
    }
    if (this.isOpposite(this.direction, next) || this.direction === next) {
      return false;
    }
    this.queuedDirection = next;
    return true;
  }

  tick(): GameSnapshot {
    if (this.status !== GameStatus.RUNNING) {
      return this.snapshot();
    }
    if (this.queuedDirection !== null) {
      this.direction = this.queuedDirection;
      this.queuedDirection = null;
    }
    const head: Point = this.snake[0];
    const next: Point = this.nextHead(head, this.direction);
    if (this.hitsWall(next)) {
      this.status = GameStatus.OVER;
      return this.snapshot();
    }

    const eating: boolean = this.samePoint(next, this.food);
    // 未进食时尾部会同时移走，因此允许蛇头进入当前尾格。
    const bodyLength: number = eating ? this.snake.length : this.snake.length - 1;
    if (this.hitsBody(next, bodyLength)) {
      this.status = GameStatus.OVER;
      return this.snapshot();
    }

    this.snake.unshift(next);
    if (eating) {
      this.score += 10;
      this.eatenCount += 1;
      this.bestScore = Math.max(this.bestScore, this.score);
      if (this.snake.length >= GameEngine.BOARD_SIZE * GameEngine.BOARD_SIZE) {
        this.status = GameStatus.WON;
      } else {
        this.food = this.generateFood();
      }
    } else {
      this.snake.pop();
    }
    return this.snapshot();
  }

  pause(): GameSnapshot {
    if (this.status === GameStatus.RUNNING) {
      this.status = GameStatus.PAUSED;
    }
    return this.snapshot();
  }

  resume(): GameSnapshot {
    if (this.status === GameStatus.PAUSED) {
      this.status = GameStatus.RUNNING;
    }
    return this.snapshot();
  }

  stop(): GameSnapshot {
    this.status = GameStatus.IDLE;
    return this.snapshot();
  }

  getSnapshot(): GameSnapshot {
    return this.snapshot();
  }

  private snapshot(): GameSnapshot {
    const result: GameSnapshot = new GameSnapshot();
    result.snake = this.snake.map((point: Point) => new Point(point.x, point.y));
    result.food = new Point(this.food.x, this.food.y);
    result.score = this.score;
    result.bestScore = this.bestScore;
    result.tickInterval = this.getTickInterval();
    result.status = this.status;
    result.difficulty = this.difficulty;
    return result;
  }

  private getTickInterval(): number {
    let base: number = 190;
    let minimum: number = 80;
    if (this.difficulty === Difficulty.EASY) {
      base = 260;
      minimum = 115;
    } else if (this.difficulty === Difficulty.HARD) {
      base = 130;
      minimum = 55;
    }
    const level: number = Math.floor(this.eatenCount / 5);
    const step: number = this.difficulty === Difficulty.HARD ? 12 : 10;
    return Math.max(minimum, base - level * step);
  }

  private nextHead(head: Point, direction: Direction): Point {
    if (direction === Direction.UP) {
      return new Point(head.x, head.y - 1);
    }
    if (direction === Direction.DOWN) {
      return new Point(head.x, head.y + 1);
    }
    if (direction === Direction.LEFT) {
      return new Point(head.x - 1, head.y);
    }
    return new Point(head.x + 1, head.y);
  }

  private hitsWall(point: Point): boolean {
    return point.x < 0 || point.y < 0 ||
      point.x >= GameEngine.BOARD_SIZE || point.y >= GameEngine.BOARD_SIZE;
  }

  private hitsBody(point: Point, length: number): boolean {
    for (let index: number = 0; index < length; index += 1) {
      if (this.samePoint(point, this.snake[index])) {
        return true;
      }
    }
    return false;
  }

  private generateFood(): Point {
    const empty: Point[] = [];
    for (let y: number = 0; y < GameEngine.BOARD_SIZE; y += 1) {
      for (let x: number = 0; x < GameEngine.BOARD_SIZE; x += 1) {
        const candidate: Point = new Point(x, y);
        if (!this.hitsBody(candidate, this.snake.length)) {
          empty.push(candidate);
        }
      }
    }
    if (empty.length === 0) {
      return new Point(-1, -1);
    }
    const index: number = Math.min(empty.length - 1, Math.floor(this.random() * empty.length));
    return empty[index];
  }

  private samePoint(left: Point, right: Point): boolean {
    return left.x === right.x && left.y === right.y;
  }

  private isOpposite(current: Direction, next: Direction): boolean {
    return (current === Direction.UP && next === Direction.DOWN) ||
      (current === Direction.DOWN && next === Direction.UP) ||
      (current === Direction.LEFT && next === Direction.RIGHT) ||
      (current === Direction.RIGHT && next === Direction.LEFT);
  }
}
