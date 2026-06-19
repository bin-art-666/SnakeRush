import { promptAction } from '@kit.ArkUI';
import { deviceInfo } from '@kit.BasicServicesKit';
import { KeyCode } from '@kit.InputKit';
import { vibrator } from '@kit.SensorServiceKit';
import { AccountProfile, AccountService, AccountStatus } from '../service/AccountService';
import { GameEngine } from '../engine/GameEngine';
import {
  ControlMode,
  Difficulty,
  difficultyLabel,
  Direction,
  GameSettings,
  GameSnapshot,
  GameStatus,
  getThemePalette,
  RankRecord,
  ThemeName,
  themeLabel,
  ThemePalette
} from '../model/GameModels';
import { StorageService } from '../service/StorageService';

enum AppPage {
  SPLASH = 'splash',
  HOME = 'home',
  DIFFICULTY = 'difficulty',
  GAME = 'game',
  RANK = 'rank',
  SETTINGS = 'settings',
  ABOUT = 'about',
  ACCOUNT = 'account'
}

@Entry
@Component
struct Index {
  private engine: GameEngine = new GameEngine();
  private boardCells: number[] = [];
  private timerId: number = -1;
  private splashTimerId: number = -1;
  private touchStartX: number = 0;
  private touchStartY: number = 0;
  private pageHistory: AppPage[] = [];
  @State page: AppPage = AppPage.SPLASH;
  @State snapshot: GameSnapshot = new GameSnapshot();
  @State settings: GameSettings = new GameSettings();
  @State ranks: RankRecord[] = [];
  @State account: AccountProfile = new AccountProfile();
  @State selectedDifficulty: Difficulty = Difficulty.NORMAL;
  @State windowWidth: number = 360;
  @State windowHeight: number = 780;
  @State showClearConfirm: boolean = false;
  @State gameResultSaved: boolean = false;
  @StorageLink('appInBackground') @Watch('onAppBackgroundChanged') appInBackground: boolean = false;
  @StorageLink('backRequestId') @Watch('onSystemBackRequested') backRequestId: number = 0;

  aboutToAppear(): void {
    for (let index: number = 0; index < GameEngine.BOARD_SIZE * GameEngine.BOARD_SIZE; index += 1) {
      this.boardCells.push(index);
    }
    this.settings = StorageService.getSettings();
    this.selectedDifficulty = this.settings.defaultDifficulty;
    this.ranks = StorageService.getRanks();
    this.account = AccountService.getProfile();
    this.snapshot.bestScore = StorageService.getBestScore();
    this.splashTimerId = setTimeout(() => {
      this.replacePage(AppPage.HOME);
    }, 1200);
    this.updateBackCapability();
  }

  aboutToDisappear(): void {
    this.stopTimer();
    if (this.splashTimerId >= 0) {
      clearTimeout(this.splashTimerId);
    }
  }

  onAppBackgroundChanged(): void {
    if (this.appInBackground && this.snapshot.status === GameStatus.RUNNING) {
      this.pauseGame();
    }
  }

  private palette(): ThemePalette {
    return getThemePalette(this.settings.theme);
  }

  private navigate(page: AppPage): void {
    if (page === this.page) {
      return;
    }
    if (this.page !== AppPage.SPLASH) {
      this.pageHistory.push(this.page);
    }
    this.page = page;
    if (page === AppPage.RANK) {
      this.ranks = StorageService.getRanks();
    }
    this.updateBackCapability();
  }

  private replacePage(page: AppPage): void {
    this.page = page;
    this.pageHistory = [];
    this.updateBackCapability();
  }

  private goBack(): void {
    if (this.page === AppPage.GAME) {
      this.stopTimer();
      this.snapshot = this.engine.stop();
    }
    if (this.pageHistory.length > 0) {
      const previous: AppPage | undefined = this.pageHistory.pop();
      if (previous !== undefined) {
        this.page = previous;
      }
    } else if (this.page !== AppPage.HOME && this.page !== AppPage.SPLASH) {
      this.page = AppPage.HOME;
    }
    if (this.page === AppPage.RANK) {
      this.ranks = StorageService.getRanks();
    }
    this.updateBackCapability();
  }

  private updateBackCapability(): void {
    AppStorage.set('canNavigateBack',
      this.page !== AppPage.HOME && this.page !== AppPage.SPLASH);
  }

  onSystemBackRequested(): void {
    this.goBack();
  }

  private startGame(): void {
    if (deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_CAR) {
      promptAction.showToast({ message: '为保障驾驶安全，车机端不开放游戏' });
      return;
    }
    this.stopTimer();
    this.gameResultSaved = false;
    this.snapshot = this.engine.start(this.selectedDifficulty, StorageService.getBestScore());
    this.navigate(AppPage.GAME);
    this.scheduleTick();
  }

  private scheduleTick(): void {
    this.stopTimer();
    if (this.snapshot.status !== GameStatus.RUNNING) {
      return;
    }
    this.timerId = setTimeout(() => {
      const previousScore: number = this.snapshot.score;
      this.snapshot = this.engine.tick();
      if (this.snapshot.score > previousScore) {
        this.vibrate(28);
      }
      if (this.snapshot.status === GameStatus.RUNNING) {
        this.scheduleTick();
      } else {
        this.vibrate(90);
        this.finishGame();
      }
    }, this.snapshot.tickInterval);
  }

  private stopTimer(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }

  private pauseGame(): void {
    this.stopTimer();
    this.snapshot = this.engine.pause();
  }

  private resumeGame(): void {
    this.snapshot = this.engine.resume();
    this.scheduleTick();
  }

  private leaveGame(): void {
    this.stopTimer();
    this.snapshot = this.engine.stop();
    this.replacePage(AppPage.HOME);
  }

  private gameBoardSize(): number {
    if (this.windowWidth > 720) {
      return Math.max(220, Math.min(this.windowWidth * 0.56, this.windowHeight - 150));
    }
    const controlsHeight: number =
      this.settings.controlMode === ControlMode.BUTTON ||
      deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_TV ? 190 : 105;
    return Math.max(210, Math.min(this.windowWidth - 32, this.windowHeight - controlsHeight));
  }

  private async finishGame(): Promise<void> {
    this.stopTimer();
    if (this.gameResultSaved || this.snapshot.score <= 0) {
      return;
    }
    this.gameResultSaved = true;
    await StorageService.saveBestScore(this.snapshot.score);
    this.ranks = await StorageService.addRank(
      new RankRecord(this.snapshot.score, this.snapshot.difficulty));
    this.snapshot.bestScore = StorageService.getBestScore();
  }

  private changeDirection(direction: Direction): void {
    this.engine.setDirection(direction);
  }

  private async vibrate(duration: number): Promise<void> {
    if (!this.settings.vibrationEnabled) {
      return;
    }
    try {
      await vibrator.startVibration({ type: 'time', duration: duration }, { usage: 'touch' });
    } catch (_) {
      // 电视、模拟器等无振动能力设备直接静默降级。
    }
  }

  private handleTouch(event: TouchEvent): void {
    if (event.touches.length === 0) {
      return;
    }
    if (event.type === TouchType.Down) {
      this.touchStartX = event.touches[0].x;
      this.touchStartY = event.touches[0].y;
    } else if (event.type === TouchType.Up) {
      const deltaX: number = event.touches[0].x - this.touchStartX;
      const deltaY: number = event.touches[0].y - this.touchStartY;
      if (Math.max(Math.abs(deltaX), Math.abs(deltaY)) < 18) {
        return;
      }
      if (Math.abs(deltaX) > Math.abs(deltaY)) {
        this.changeDirection(deltaX > 0 ? Direction.RIGHT : Direction.LEFT);
      } else {
        this.changeDirection(deltaY > 0 ? Direction.DOWN : Direction.UP);
      }
    }
  }

  private handleKey(event: KeyEvent): void {
    if (event.type !== KeyType.Down) {
      return;
    }
    if (event.keyCode === KeyCode.KEYCODE_DPAD_UP) {
      this.changeDirection(Direction.UP);
    } else if (event.keyCode === KeyCode.KEYCODE_DPAD_DOWN) {
      this.changeDirection(Direction.DOWN);
    } else if (event.keyCode === KeyCode.KEYCODE_DPAD_LEFT) {
      this.changeDirection(Direction.LEFT);
    } else if (event.keyCode === KeyCode.KEYCODE_DPAD_RIGHT) {
      this.changeDirection(Direction.RIGHT);
    } else if (event.keyCode === KeyCode.KEYCODE_SPACE) {
      if (this.snapshot.status === GameStatus.RUNNING) {
        this.pauseGame();
      } else if (this.snapshot.status === GameStatus.PAUSED) {
        this.resumeGame();
      }
    }
  }

  private snakeIndex(cell: number): number {
    const x: number = cell % GameEngine.BOARD_SIZE;
    const y: number = Math.floor(cell / GameEngine.BOARD_SIZE);
    for (let index: number = 0; index < this.snapshot.snake.length; index += 1) {
      if (this.snapshot.snake[index].x === x && this.snapshot.snake[index].y === y) {
        return index;
      }
    }
    return -1;
  }

  private isFood(cell: number): boolean {
    return this.snapshot.food.x === cell % GameEngine.BOARD_SIZE &&
      this.snapshot.food.y === Math.floor(cell / GameEngine.BOARD_SIZE);
  }

  private updateSettings(): void {
    StorageService.saveSettings(this.settings);
    const refreshed: GameSettings = new GameSettings();
    refreshed.controlMode = this.settings.controlMode;
    refreshed.theme = this.settings.theme;
    refreshed.soundEnabled = this.settings.soundEnabled;
    refreshed.vibrationEnabled = this.settings.vibrationEnabled;
    refreshed.defaultDifficulty = this.settings.defaultDifficulty;
    this.settings = refreshed;
  }

  private async login(): Promise<void> {
    if (this.account.status === AccountStatus.AUTHORIZING) {
      return;
    }
    this.account.status = AccountStatus.AUTHORIZING;
    const authorizing: AccountProfile = new AccountProfile();
    authorizing.status = AccountStatus.AUTHORIZING;
    authorizing.name = this.account.name;
    authorizing.avatar = this.account.avatar;
    this.account = authorizing;
    this.account = await AccountService.signIn();
    promptAction.showToast({ message: this.account.message });
  }

  private async logout(revoke: boolean): Promise<void> {
    this.account = await AccountService.signOut(revoke);
    promptAction.showToast({ message: revoke ? '已退出并取消授权' : '已退出登录' });
  }

  @Builder
  private GlassButton(label: string, action: () => void, primary: boolean = false): void {
    Button(label)
      .width('100%')
      .height(52)
      .fontSize(17)
      .fontWeight(FontWeight.Medium)
      .fontColor(primary ? this.palette().background : this.palette().text)
      .backgroundColor(primary ? this.palette().primary : this.palette().panel)
      .border({ width: 1, color: primary ? this.palette().primary : this.palette().panelBorder })
      .borderRadius(18)
      .shadow({ radius: primary ? 18 : 8, color: primary ? this.palette().primary + '55' : '#00000033' })
      .stateEffect(true)
      .onClick(action)
  }

  @Builder
  private PageHeader(title: string): void {
    Row() {
      Button('‹')
        .width(44)
        .height(44)
        .fontSize(28)
        .fontColor(this.palette().text)
        .backgroundColor(this.palette().panel)
        .borderRadius(16)
        .onClick(() => this.goBack())
      Text(title)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().text)
        .margin({ left: 14 })
      Blank()
    }
    .width('100%')
  }

  @Builder
  private SplashPage(): void {
    Column({ space: 18 }) {
      Text('S')
        .width(92)
        .height(92)
        .textAlign(TextAlign.Center)
        .fontSize(58)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.palette().background)
        .backgroundColor(this.palette().primary)
        .borderRadius(30)
        .shadow({ radius: 34, color: this.palette().primary + '88' })
      Text('SNAKE RUSH')
        .fontSize(32)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(3)
        .fontColor(this.palette().text)
      Text('蛇影冲刺')
        .fontSize(18)
        .fontColor(this.palette().muted)
      LoadingProgress()
        .width(32)
        .height(32)
        .color(this.palette().primary)
        .margin({ top: 30 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .onClick(() => this.replacePage(AppPage.HOME))
  }

  @Builder
  private AccountChip(): void {
    Row({ space: 9 }) {
      if (this.account.avatar.length > 0) {
        Image(this.account.avatar)
          .width(34)
          .height(34)
          .borderRadius(17)
          .objectFit(ImageFit.Cover)
      } else {
        Text(this.account.status === AccountStatus.SIGNED_IN ? '华' : '游')
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .fontSize(15)
          .fontColor(this.palette().background)
          .backgroundColor(this.palette().primary)
          .borderRadius(17)
      }
      Text(this.account.status === AccountStatus.SIGNED_IN ? this.account.name : '游客')
        .fontSize(14)
        .fontColor(this.palette().text)
        .maxLines(1)
    }
    .padding({ left: 8, right: 14, top: 7, bottom: 7 })
    .backgroundColor(this.palette().panel)
    .border({ width: 1, color: this.palette().panelBorder })
    .borderRadius(24)
    .onClick(() => this.navigate(AppPage.ACCOUNT))
  }

  @Builder
  private HomePage(): void {
    Scroll() {
      Column({ space: 18 }) {
        Row() {
          Column() {
            Text('SNAKE RUSH')
              .fontSize(this.windowWidth > 700 ? 36 : 29)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.palette().text)
            Text('蛇影冲刺')
              .fontSize(15)
              .fontColor(this.palette().primary)
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          this.AccountChip()
        }
        .width('100%')

        Column({ space: 10 }) {
          Text('速度、策略与反应的玻璃冲刺。')
            .fontSize(this.windowWidth > 700 ? 24 : 19)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.palette().text)
          Text('在流光棋盘中刷新你的最长蛇影')
            .fontSize(14)
            .fontColor(this.palette().muted)
          Row({ space: 22 }) {
            Column({ space: 4 }) {
              Text(StorageService.getBestScore().toString())
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().primary)
              Text('历史最高分').fontSize(12).fontColor(this.palette().muted)
            }
            Divider().vertical(true).height(45).color(this.palette().panelBorder)
            Column({ space: 4 }) {
              Text(themeLabel(this.settings.theme))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.palette().secondary)
              Text('当前主题').fontSize(12).fontColor(this.palette().muted)
            }
          }
          .margin({ top: 20 })
        }
        .width('100%')
        .padding(24)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.palette().panel)
        .border({ width: 1, color: this.palette().panelBorder })
        .borderRadius(28)
        .shadow({ radius: 28, color: '#00000044' })

        this.GlassButton(deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_CAR ?
          '驾驶时不可游玩' : '开始游戏', () => this.navigate(AppPage.DIFFICULTY), true)
        this.GlassButton('排行榜', () => this.navigate(AppPage.RANK))
        this.GlassButton('设置', () => this.navigate(AppPage.SETTINGS))
        this.GlassButton('关于 Snake Rush', () => this.navigate(AppPage.ABOUT))
      }
      .width('100%')
      .padding(this.windowWidth > 700 ? 48 : 22)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private DifficultyCard(value: Difficulty, title: string, description: string, color: string): void {
    Row({ space: 16 }) {
      Text(value === Difficulty.EASY ? '○' : value === Difficulty.HARD ? '◆' : '◇')
        .width(46)
        .fontSize(30)
        .fontColor(color)
      Column({ space: 5 }) {
        Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
        Text(description).fontSize(13).fontColor(this.palette().muted)
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      if (this.selectedDifficulty === value) {
        Text('✓').fontSize(24).fontColor(this.palette().primary)
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor(this.selectedDifficulty === value ? this.palette().backgroundGlow : this.palette().panel)
    .border({ width: 1.5, color: this.selectedDifficulty === value ? this.palette().primary : this.palette().panelBorder })
    .borderRadius(22)
    .onClick(() => this.selectedDifficulty = value)
  }

  @Builder
  private DifficultyPage(): void {
    Column({ space: 18 }) {
      this.PageHeader('选择难度')
      Text('每吃 5 个食物，蛇的速度会提升一级。')
        .width('100%')
        .fontSize(14)
        .fontColor(this.palette().muted)
      this.DifficultyCard(Difficulty.EASY, '简单', '悠闲节奏 · 适合初次体验', '#72E7A7')
      this.DifficultyCard(Difficulty.NORMAL, '普通', '标准节奏 · 速度逐渐提升', '#59E2FF')
      this.DifficultyCard(Difficulty.HARD, '困难', '高速开局 · 更强加速', '#FF7A8A')
      Blank()
      this.GlassButton('进入棋盘', () => this.startGame(), true)
    }
    .width('100%')
    .height('100%')
    .padding(this.windowWidth > 700 ? 48 : 22)
  }

  @Builder
  private ScoreTile(label: string, value: string): void {
    Column({ space: 2 }) {
      Text(value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
      Text(label).fontSize(11).fontColor(this.palette().muted)
    }
    .padding({ left: 14, right: 14, top: 8, bottom: 8 })
    .backgroundColor(this.palette().panel)
    .borderRadius(14)
  }

  @Builder
  private GameBoard(): void {
    Grid() {
      ForEach(this.boardCells, (cell: number) => {
        GridItem() {
          if (this.snakeIndex(cell) >= 0) {
            Row()
              .width('82%')
              .height('82%')
              .backgroundColor(this.snakeIndex(cell) === 0 ? this.palette().secondary : this.palette().primary)
              .borderRadius(this.snakeIndex(cell) === 0 ? 5 : 4)
              .shadow({
                radius: this.snakeIndex(cell) === 0 ? 8 : 3,
                color: this.palette().primary + '88'
              })
          } else if (this.isFood(cell)) {
            Row()
              .width('66%')
              .height('66%')
              .backgroundColor(this.palette().food)
              .borderRadius(20)
              .shadow({ radius: 12, color: this.palette().food + 'AA' })
          } else {
            Row()
              .width('100%')
              .height('100%')
              .border({ width: 0.25, color: this.palette().panelBorder })
          }
        }
      }, (cell: number) => cell.toString())
    }
    .columnsTemplate('repeat(20, 1fr)')
    .rowsTemplate('repeat(20, 1fr)')
    .width(this.gameBoardSize())
    .height(this.gameBoardSize())
    .padding(5)
    .backgroundColor(this.palette().panel)
    .border({ width: 1, color: this.palette().panelBorder })
    .borderRadius(24)
    .shadow({ radius: 28, color: this.palette().backgroundGlow + '88' })
    .onTouch((event: TouchEvent) => this.handleTouch(event))
    .focusable(true)
    .defaultFocus(true)
    .onKeyEvent((event: KeyEvent) => this.handleKey(event))
  }

  @Builder
  private DirectionButton(label: string, direction: Direction): void {
    Button(label)
      .width(58)
      .height(52)
      .fontSize(22)
      .fontColor(this.palette().text)
      .backgroundColor(this.palette().panel)
      .border({ width: 1, color: this.palette().panelBorder })
      .borderRadius(16)
      .onClick(() => this.changeDirection(direction))
  }

  @Builder
  private DirectionPad(): void {
    Column({ space: 7 }) {
      this.DirectionButton('↑', Direction.UP)
      Row({ space: 7 }) {
        this.DirectionButton('←', Direction.LEFT)
        this.DirectionButton('↓', Direction.DOWN)
        this.DirectionButton('→', Direction.RIGHT)
      }
    }
  }

  @Builder
  private GamePage(): void {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 14 }) {
        Row({ space: 8 }) {
          Button('‹')
            .width(42).height(42).fontSize(27).fontColor(this.palette().text)
            .backgroundColor(this.palette().panel).borderRadius(14)
            .onClick(() => this.goBack())
          this.ScoreTile('分数', this.snapshot.score.toString())
          this.ScoreTile('最高', this.snapshot.bestScore.toString())
          Blank()
          Button(this.snapshot.status === GameStatus.PAUSED ? '▶' : 'Ⅱ')
            .width(42).height(42).fontSize(18).fontColor(this.palette().text)
            .backgroundColor(this.palette().panel).borderRadius(14)
            .onClick(() => this.snapshot.status === GameStatus.PAUSED ? this.resumeGame() : this.pauseGame())
        }
        .width('100%')
        Text(difficultyLabel(this.snapshot.difficulty) + ' · ' +
          Math.round(1000 / this.snapshot.tickInterval).toString() + ' 格/秒')
          .width('100%').fontSize(12).fontColor(this.palette().muted)
        if (this.windowWidth > 720) {
          Row({ space: 28 }) {
            Column() {
              this.GameBoard()
            }
            .width('62%')
            Column({ space: 20 }) {
              Text(this.settings.controlMode === ControlMode.SWIPE ? '滑动或方向键控制' : '方向键控制')
                .fontSize(14).fontColor(this.palette().muted)
              this.DirectionPad()
            }
            .width('30%')
          }
          .width('100%')
        } else {
          this.GameBoard()
          if (this.settings.controlMode === ControlMode.BUTTON ||
            deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_TV) {
            this.DirectionPad()
          } else {
            Text('在棋盘上滑动控制方向')
              .fontSize(13)
              .fontColor(this.palette().muted)
          }
        }
      }
      .width('100%')
      .height('100%')
      .padding(this.windowWidth > 700 ? 34 : 16)
      .alignItems(HorizontalAlign.Center)

      if (this.snapshot.status === GameStatus.PAUSED) {
        Column({ space: 16 }) {
          Text('游戏暂停').fontSize(27).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
          Text('当前得分 ' + this.snapshot.score.toString()).fontSize(15).fontColor(this.palette().muted)
          this.GlassButton('继续游戏', () => this.resumeGame(), true)
          this.GlassButton('重新开始', () => this.startGame())
          this.GlassButton('返回首页', () => this.leaveGame())
        }
        .width(this.windowWidth > 700 ? 380 : '84%')
        .padding(24)
        .backgroundColor(this.palette().panel)
        .border({ width: 1, color: this.palette().panelBorder })
        .borderRadius(28)
        .shadow({ radius: 40, color: '#000000AA' })
      }

      if (this.snapshot.status === GameStatus.OVER || this.snapshot.status === GameStatus.WON) {
        Column({ space: 16 }) {
          Text(this.snapshot.status === GameStatus.WON ? '完美通关' : 'GAME OVER')
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor(this.palette().food)
          Text(this.snapshot.score.toString())
            .fontSize(54).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
          Text(this.snapshot.score >= this.snapshot.bestScore && this.snapshot.score > 0 ?
            '✨ 新的最高纪录' : '最高分 ' + this.snapshot.bestScore.toString())
            .fontSize(15).fontColor(this.palette().muted)
          this.GlassButton('再来一局', () => this.startGame(), true)
          this.GlassButton('查看排行榜', () => {
            this.stopTimer();
            this.navigate(AppPage.RANK);
          })
          this.GlassButton('返回首页', () => this.leaveGame())
        }
        .width(this.windowWidth > 700 ? 390 : '84%')
        .padding(24)
        .backgroundColor(this.palette().panel)
        .border({ width: 1, color: this.palette().panelBorder })
        .borderRadius(28)
        .shadow({ radius: 40, color: '#000000AA' })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private RankPage(): void {
    Column({ space: 18 }) {
      this.PageHeader('本地排行榜')
      Text('成绩仅保存在本机 · 当前展示身份：' +
        (this.account.status === AccountStatus.SIGNED_IN ? this.account.name : '玩家'))
        .width('100%').fontSize(13).fontColor(this.palette().muted)
      if (this.ranks.length === 0) {
        Column({ space: 12 }) {
          Text('♕').fontSize(52).fontColor(this.palette().primary)
          Text('还没有成绩').fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
          Text('完成一局后，你的最佳表现会出现在这里。')
            .fontSize(13).fontColor(this.palette().muted)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.ranks, (record: RankRecord, index: number) => {
            ListItem() {
              Row({ space: 14 }) {
                Text((index + 1).toString())
                  .width(36).fontSize(20).fontWeight(FontWeight.Bold)
                  .fontColor(index < 3 ? this.palette().food : this.palette().muted)
                Column({ space: 3 }) {
                  Text(this.account.status === AccountStatus.SIGNED_IN ? this.account.name : '玩家')
                    .fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette().text)
                  Text(difficultyLabel(record.difficulty) + ' · ' +
                    new Date(record.timestamp).toLocaleDateString())
                    .fontSize(12).fontColor(this.palette().muted)
                }
                .alignItems(HorizontalAlign.Start)
                Blank()
                Text(record.score.toString())
                  .fontSize(23).fontWeight(FontWeight.Bold).fontColor(this.palette().primary)
              }
              .width('100%')
              .padding(17)
              .backgroundColor(this.palette().panel)
              .border({ width: 1, color: this.palette().panelBorder })
              .borderRadius(18)
            }
          }, (record: RankRecord) => record.timestamp.toString())
        }
        .layoutWeight(1)
        .width('100%')
      }
      if (this.ranks.length > 0) {
        this.GlassButton(this.showClearConfirm ? '再次点击确认清空' : '清空排行榜', async () => {
          if (!this.showClearConfirm) {
            this.showClearConfirm = true;
            return;
          }
          await StorageService.clearRanks();
          this.ranks = [];
          this.showClearConfirm = false;
        })
      }
    }
    .width('100%')
    .height('100%')
    .padding(this.windowWidth > 700 ? 48 : 22)
  }

  @Builder
  private SettingRow(title: string, subtitle: string, kind: number): void {
    Row({ space: 14 }) {
      Column({ space: 4 }) {
        Text(title).fontSize(16).fontWeight(FontWeight.Medium).fontColor(this.palette().text)
        Text(subtitle).fontSize(12).fontColor(this.palette().muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (kind === 0) {
        Button(this.settings.controlMode === ControlMode.SWIPE ? '滑动' : '按钮')
          .fontColor(this.palette().primary).backgroundColor(this.palette().backgroundGlow)
          .onClick(() => {
            this.settings.controlMode = this.settings.controlMode === ControlMode.SWIPE ?
              ControlMode.BUTTON : ControlMode.SWIPE;
            this.updateSettings();
          })
      } else if (kind === 1) {
        Toggle({ type: ToggleType.Switch, isOn: this.settings.soundEnabled })
          .selectedColor(this.palette().primary)
          .onChange((value: boolean) => {
            this.settings.soundEnabled = value;
            this.updateSettings();
          })
      } else if (kind === 2) {
        Toggle({ type: ToggleType.Switch, isOn: this.settings.vibrationEnabled })
          .selectedColor(this.palette().primary)
          .onChange((value: boolean) => {
            this.settings.vibrationEnabled = value;
            this.updateSettings();
          })
      } else if (kind === 3) {
        Button(difficultyLabel(this.settings.defaultDifficulty))
          .fontColor(this.palette().primary).backgroundColor(this.palette().backgroundGlow)
          .onClick(() => {
            if (this.settings.defaultDifficulty === Difficulty.EASY) {
              this.settings.defaultDifficulty = Difficulty.NORMAL;
            } else if (this.settings.defaultDifficulty === Difficulty.NORMAL) {
              this.settings.defaultDifficulty = Difficulty.HARD;
            } else {
              this.settings.defaultDifficulty = Difficulty.EASY;
            }
            this.selectedDifficulty = this.settings.defaultDifficulty;
            this.updateSettings();
          })
      } else {
        Button(!AccountService.isAvailable() ? '不可用' :
          (this.account.status === AccountStatus.SIGNED_IN ? this.account.name : '登录'))
          .fontColor(this.palette().primary).backgroundColor(this.palette().backgroundGlow)
          .onClick(() => this.navigate(AppPage.ACCOUNT))
      }
    }
    .width('100%')
    .padding(17)
    .backgroundColor(this.palette().panel)
    .border({ width: 1, color: this.palette().panelBorder })
    .borderRadius(18)
  }

  @Builder
  private SettingsPage(): void {
    Scroll() {
      Column({ space: 14 }) {
        this.PageHeader('设置')
        this.SettingRow('控制方式', '游戏中的主要触控方式', 0)
        this.SettingRow('音效', '吃到食物与结算提示', 1)
        this.SettingRow('振动反馈', '支持设备上提供轻触反馈', 2)
        Text('主题').width('100%').fontSize(15).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
        Row({ space: 8 }) {
          ForEach([ThemeName.CLASSIC, ThemeName.ICE, ThemeName.NEON, ThemeName.STAR],
            (theme: ThemeName) => {
              Button(themeLabel(theme))
                .layoutWeight(1)
                .fontSize(13)
                .fontColor(this.settings.theme === theme ? this.palette().background : this.palette().text)
                .backgroundColor(this.settings.theme === theme ? this.palette().primary : this.palette().panel)
                .onClick(() => {
                  this.settings.theme = theme;
                  this.updateSettings();
                })
            })
        }
        this.SettingRow('默认难度', '进入难度页时预先选择', 3)
        this.SettingRow('华为账号', '可选登录，仅用于本机身份展示', 4)
      }
      .width('100%')
      .padding(this.windowWidth > 700 ? 48 : 22)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  private AccountPage(): void {
    Column({ space: 18 }) {
      this.PageHeader('华为账号')
      Column({ space: 14 }) {
        if (this.account.avatar.length > 0) {
          Image(this.account.avatar).width(84).height(84).borderRadius(42).objectFit(ImageFit.Cover)
        } else {
          Text(this.account.status === AccountStatus.SIGNED_IN ? '华' : '游')
            .width(84).height(84).textAlign(TextAlign.Center).fontSize(36)
            .fontColor(this.palette().background).backgroundColor(this.palette().primary).borderRadius(42)
        }
        Text(this.account.status === AccountStatus.SIGNED_IN ? this.account.name : '游客模式')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
        Text(this.account.status === AccountStatus.SIGNED_IN ?
          '账号资料仅用于本机展示，成绩不会上传。' :
          '无需登录也可以游玩全部基础内容。')
          .fontSize(14).fontColor(this.palette().muted).textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding(28)
      .backgroundColor(this.palette().panel)
      .border({ width: 1, color: this.palette().panelBorder })
      .borderRadius(28)
      if (this.account.status === AccountStatus.SIGNED_IN) {
        this.GlassButton('退出登录', () => this.logout(false))
        this.GlassButton('退出并取消授权', () => this.logout(true))
      } else if (AccountService.isAvailable()) {
        this.GlassButton(this.account.status === AccountStatus.AUTHORIZING ?
          '正在打开华为账号…' : '使用华为账号登录', () => this.login(), true)
        Text('将请求最小范围的 profile 权限，用于读取昵称和头像。')
          .fontSize(12).fontColor(this.palette().muted).textAlign(TextAlign.Center)
      } else {
        Text('当前设备类型不提供 Account Kit 登录，游戏将保持游客模式。')
          .fontSize(14).fontColor(this.palette().muted).textAlign(TextAlign.Center)
      }
      Blank()
    }
    .width('100%')
    .height('100%')
    .padding(this.windowWidth > 700 ? 48 : 22)
  }

  @Builder
  private AboutPage(): void {
    Scroll() {
      Column({ space: 18 }) {
        this.PageHeader('关于')
        Text('Snake Rush')
          .fontSize(34).fontWeight(FontWeight.Bold).fontColor(this.palette().primary)
        Text('蛇影冲刺 · 1.0.0')
          .fontSize(15).fontColor(this.palette().muted)
        Column({ space: 12 }) {
          Text('经典玩法，现代光影')
            .fontSize(20).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
          Text('Snake Rush 使用 ArkTS 与 ArkUI 构建，在经典贪吃蛇规则上加入液态玻璃界面、渐进速度、主题和本地排行榜。')
            .fontSize(14).lineHeight(24).fontColor(this.palette().muted)
        }
        .width('100%').padding(22).alignItems(HorizontalAlign.Start)
        .backgroundColor(this.palette().panel).borderRadius(22)
        Text('隐私说明')
          .width('100%').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
        Text('华为账号登录完全可选。应用仅在获得授权后读取昵称与头像用于本机身份展示，不保存访问令牌、授权码，不上传游戏成绩或设置。退出登录后会清除本地账号展示缓存。')
          .width('100%').fontSize(14).lineHeight(24).fontColor(this.palette().muted)
        Text('设备说明')
          .width('100%').fontSize(19).fontWeight(FontWeight.Bold).fontColor(this.palette().text)
        Text('手机、平板、2in1 与电视支持完整游戏；手表使用紧凑布局；车机端出于驾驶安全仅开放资料、设置和排行榜。')
          .width('100%').fontSize(14).lineHeight(24).fontColor(this.palette().muted)
      }
      .width('100%')
      .padding(this.windowWidth > 700 ? 48 : 22)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 145,
          colors: [[this.palette().backgroundGlow, 0.0], [this.palette().background, 0.46], ['#02060A', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      if (this.page === AppPage.SPLASH) {
        this.SplashPage()
      } else if (this.page === AppPage.HOME) {
        this.HomePage()
      } else if (this.page === AppPage.DIFFICULTY) {
        this.DifficultyPage()
      } else if (this.page === AppPage.GAME) {
        this.GamePage()
      } else if (this.page === AppPage.RANK) {
        this.RankPage()
      } else if (this.page === AppPage.SETTINGS) {
        this.SettingsPage()
      } else if (this.page === AppPage.ACCOUNT) {
        this.AccountPage()
      } else {
        this.AboutPage()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      this.windowWidth = Number(newValue.width);
      this.windowHeight = Number(newValue.height);
    })
  }
}
