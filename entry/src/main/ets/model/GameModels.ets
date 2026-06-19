export enum Direction {
  UP = 'up',
  DOWN = 'down',
  LEFT = 'left',
  RIGHT = 'right'
}

export enum Difficulty {
  EASY = 'easy',
  NORMAL = 'normal',
  HARD = 'hard'
}

export enum GameStatus {
  IDLE = 'idle',
  RUNNING = 'running',
  PAUSED = 'paused',
  OVER = 'over',
  WON = 'won'
}

export enum ControlMode {
  SWIPE = 'swipe',
  BUTTON = 'button'
}

export enum DirectionPadLayout {
  CROSS = 'cross',
  COMPACT = 'compact'
}

export enum ThemeName {
  CLASSIC = 'classic',
  ICE = 'ice',
  NEON = 'neon',
  STAR = 'star'
}

export class Point {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

export class GameSnapshot {
  snake: Point[] = [];
  food: Point = new Point(0, 0);
  score: number = 0;
  bestScore: number = 0;
  tickInterval: number = 190;
  status: GameStatus = GameStatus.IDLE;
  difficulty: Difficulty = Difficulty.NORMAL;
}

export class RankRecord {
  score: number;
  difficulty: Difficulty;
  timestamp: number;

  constructor(score: number, difficulty: Difficulty, timestamp: number = Date.now()) {
    this.score = score;
    this.difficulty = difficulty;
    this.timestamp = timestamp;
  }
}

export class GameSettings {
  controlMode: ControlMode = ControlMode.SWIPE;
  directionButtonSize: number = 58;
  directionPadLayout: DirectionPadLayout = DirectionPadLayout.COMPACT;
  theme: ThemeName = ThemeName.ICE;
  soundEnabled: boolean = true;
  vibrationEnabled: boolean = true;
  defaultDifficulty: Difficulty = Difficulty.NORMAL;
}

export class ThemePalette {
  background: string;
  backgroundGlow: string;
  panel: string;
  panelBorder: string;
  primary: string;
  secondary: string;
  food: string;
  text: string;
  muted: string;

  constructor(background: string, backgroundGlow: string, panel: string, panelBorder: string,
    primary: string, secondary: string, food: string, text: string, muted: string) {
    this.background = background;
    this.backgroundGlow = backgroundGlow;
    this.panel = panel;
    this.panelBorder = panelBorder;
    this.primary = primary;
    this.secondary = secondary;
    this.food = food;
    this.text = text;
    this.muted = muted;
  }
}

export function getThemePalette(theme: ThemeName): ThemePalette {
  switch (theme) {
    case ThemeName.CLASSIC:
      return new ThemePalette('#07150F', '#123B2A', '#182A23DD', '#67E8A455',
        '#5EF2A1', '#A8FFD0', '#FFB454', '#F5FFF9', '#9AC5AE');
    case ThemeName.NEON:
      return new ThemePalette('#100923', '#391C70', '#24183DDD', '#C27AFF55',
        '#54F3FF', '#C06CFF', '#FF4FA3', '#FFF7FF', '#C1A9D9');
    case ThemeName.STAR:
      return new ThemePalette('#05091A', '#172A66', '#111A36DD', '#8BA9FF55',
        '#8DB4FF', '#D3DEFF', '#FFD36A', '#F7F9FF', '#A7B1D1');
    case ThemeName.ICE:
    default:
      return new ThemePalette('#06121D', '#0B3C57', '#102739DD', '#6AD8FF55',
        '#59E2FF', '#8BF7D2', '#FF8C68', '#F4FCFF', '#91B5C8');
  }
}

export function difficultyLabel(value: Difficulty): string {
  if (value === Difficulty.EASY) {
    return '简单';
  }
  if (value === Difficulty.HARD) {
    return '困难';
  }
  return '普通';
}

export function themeLabel(value: ThemeName): string {
  switch (value) {
    case ThemeName.CLASSIC:
      return '经典';
    case ThemeName.NEON:
      return '霓虹';
    case ThemeName.STAR:
      return '星空';
    case ThemeName.ICE:
    default:
      return '冰蓝';
  }
}
