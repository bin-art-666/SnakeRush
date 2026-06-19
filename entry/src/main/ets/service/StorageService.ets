import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import {
  ControlMode,
  DirectionPadLayout,
  Difficulty,
  GameSettings,
  RankRecord,
  ThemeName
} from '../model/GameModels';

class StoredSettings {
  controlMode: string = ControlMode.SWIPE;
  directionButtonSize: number = 58;
  directionPadLayout: string = DirectionPadLayout.COMPACT;
  theme: string = ThemeName.ICE;
  soundEnabled: boolean = true;
  vibrationEnabled: boolean = true;
  defaultDifficulty: string = Difficulty.NORMAL;
}

class StoredRank {
  score: number = 0;
  difficulty: string = Difficulty.NORMAL;
  timestamp: number = 0;
}

export class StorageService {
  private static store: preferences.Preferences | null = null;
  private static readonly FILE_NAME: string = 'snake_rush_preferences';
  private static readonly BEST_SCORE: string = 'best_score';
  private static readonly SETTINGS: string = 'settings';
  private static readonly RANKS: string = 'ranks';
  private static readonly ACCOUNT_NAME: string = 'account_name';
  private static readonly ACCOUNT_AVATAR: string = 'account_avatar';

  static async init(context: common.Context): Promise<void> {
    if (StorageService.store === null) {
      StorageService.store = await preferences.getPreferences(context, StorageService.FILE_NAME);
    }
  }

  static getBestScore(): number {
    return Number(StorageService.store?.getSync(StorageService.BEST_SCORE, 0) ?? 0);
  }

  static async saveBestScore(score: number): Promise<void> {
    if (StorageService.store === null || score <= StorageService.getBestScore()) {
      return;
    }
    StorageService.store.putSync(StorageService.BEST_SCORE, score);
    await StorageService.store.flush();
  }

  static getSettings(): GameSettings {
    const result: GameSettings = new GameSettings();
    const text: string = String(StorageService.store?.getSync(StorageService.SETTINGS, '') ?? '');
    if (text.length === 0) {
      return result;
    }
    try {
      const value: StoredSettings = JSON.parse(text) as StoredSettings;
      result.controlMode = value.controlMode as ControlMode;
      result.directionButtonSize = Math.max(44, Math.min(80, value.directionButtonSize ?? 58));
      result.directionPadLayout =
        (value.directionPadLayout ?? DirectionPadLayout.COMPACT) as DirectionPadLayout;
      result.theme = value.theme as ThemeName;
      result.soundEnabled = value.soundEnabled;
      result.vibrationEnabled = value.vibrationEnabled;
      result.defaultDifficulty = value.defaultDifficulty as Difficulty;
    } catch (_) {
      return new GameSettings();
    }
    return result;
  }

  static async saveSettings(settings: GameSettings): Promise<void> {
    if (StorageService.store === null) {
      return;
    }
    const value: StoredSettings = new StoredSettings();
    value.controlMode = settings.controlMode;
    value.directionButtonSize = settings.directionButtonSize;
    value.directionPadLayout = settings.directionPadLayout;
    value.theme = settings.theme;
    value.soundEnabled = settings.soundEnabled;
    value.vibrationEnabled = settings.vibrationEnabled;
    value.defaultDifficulty = settings.defaultDifficulty;
    StorageService.store.putSync(StorageService.SETTINGS, JSON.stringify(value));
    await StorageService.store.flush();
  }

  static getRanks(): RankRecord[] {
    const text: string = String(StorageService.store?.getSync(StorageService.RANKS, '[]') ?? '[]');
    try {
      const stored: StoredRank[] = JSON.parse(text) as StoredRank[];
      return stored.map((item: StoredRank) =>
        new RankRecord(item.score, item.difficulty as Difficulty, item.timestamp));
    } catch (_) {
      return [];
    }
  }

  static async addRank(record: RankRecord): Promise<RankRecord[]> {
    const ranks: RankRecord[] = StorageService.getRanks();
    ranks.push(record);
    ranks.sort((left: RankRecord, right: RankRecord) => {
      if (right.score !== left.score) {
        return right.score - left.score;
      }
      return right.timestamp - left.timestamp;
    });
    const topTen: RankRecord[] = ranks.slice(0, 10);
    if (StorageService.store !== null) {
      StorageService.store.putSync(StorageService.RANKS, JSON.stringify(topTen));
      await StorageService.store.flush();
    }
    return topTen;
  }

  static async clearRanks(): Promise<void> {
    if (StorageService.store === null) {
      return;
    }
    StorageService.store.putSync(StorageService.RANKS, '[]');
    await StorageService.store.flush();
  }

  static getCachedAccount(): string[] {
    return [
      String(StorageService.store?.getSync(StorageService.ACCOUNT_NAME, '') ?? ''),
      String(StorageService.store?.getSync(StorageService.ACCOUNT_AVATAR, '') ?? '')
    ];
  }

  static async saveCachedAccount(name: string, avatar: string): Promise<void> {
    if (StorageService.store === null) {
      return;
    }
    StorageService.store.putSync(StorageService.ACCOUNT_NAME, name);
    StorageService.store.putSync(StorageService.ACCOUNT_AVATAR, avatar);
    await StorageService.store.flush();
  }

  static async clearCachedAccount(): Promise<void> {
    if (StorageService.store === null) {
      return;
    }
    StorageService.store.deleteSync(StorageService.ACCOUNT_NAME);
    StorageService.store.deleteSync(StorageService.ACCOUNT_AVATAR);
    await StorageService.store.flush();
  }
}
