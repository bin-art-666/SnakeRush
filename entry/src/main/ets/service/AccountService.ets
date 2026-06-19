import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { BusinessError, deviceInfo } from '@kit.BasicServicesKit';
import { StorageService } from './StorageService';

export enum AccountStatus {
  GUEST = 'guest',
  AUTHORIZING = 'authorizing',
  SIGNED_IN = 'signed_in',
  ERROR = 'error'
}

export class AccountProfile {
  status: AccountStatus = AccountStatus.GUEST;
  name: string = '玩家';
  avatar: string = '';
  message: string = '';
}

export class AccountService {
  private static context: common.Context | null = null;
  private static profile: AccountProfile = new AccountProfile();

  static init(context: common.Context): void {
    AccountService.context = context;
    const cached: string[] = StorageService.getCachedAccount();
    if (cached[0].length > 0) {
      AccountService.profile.status = AccountStatus.SIGNED_IN;
      AccountService.profile.name = cached[0];
      AccountService.profile.avatar = cached[1];
    }
  }

  static getProfile(): AccountProfile {
    const result: AccountProfile = new AccountProfile();
    result.status = AccountService.profile.status;
    result.name = AccountService.profile.name;
    result.avatar = AccountService.profile.avatar;
    result.message = AccountService.profile.message;
    return result;
  }

  static isAvailable(): boolean {
    return AccountService.context !== null &&
      (deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_DEFAULT ||
        deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_PHONE ||
        deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_TABLET ||
        deviceInfo.deviceType === deviceInfo.DeviceTypes.TYPE_2IN1);
  }

  static async signIn(): Promise<AccountProfile> {
    if (!AccountService.isAvailable() || AccountService.context === null) {
      return AccountService.fail('当前设备暂不支持华为账号登录');
    }
    AccountService.profile.status = AccountStatus.AUTHORIZING;
    AccountService.profile.message = '';
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const request: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest();
      // 只请求头像和昵称，不请求手机号、邮箱、授权码或令牌。
      request.scopes = ['profile'];
      request.forceAuthorization = false;
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(AccountService.context);
      const response: authentication.AuthenticationResponse = await controller.executeRequest(request);
      const authResponse: authentication.AuthorizationWithHuaweiIDResponse =
        response as authentication.AuthorizationWithHuaweiIDResponse;
      const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = authResponse.data;
      if (credential === undefined) {
        return AccountService.fail('未获取到账号资料');
      }
      AccountService.profile.status = AccountStatus.SIGNED_IN;
      AccountService.profile.name = credential.nickName ?? '华为用户';
      AccountService.profile.avatar = credential.avatarUri ?? '';
      AccountService.profile.message = '登录成功';
      await StorageService.saveCachedAccount(AccountService.profile.name, AccountService.profile.avatar);
      return AccountService.getProfile();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      const canceled: boolean = businessError.code === 1001502012 || businessError.code === 1001500002;
      return AccountService.fail(canceled ? '已取消登录' : '登录暂不可用，请检查 Account Kit 配置');
    }
  }

  static async signOut(revokeAuthorization: boolean = false): Promise<AccountProfile> {
    if (revokeAuthorization && AccountService.context !== null) {
      try {
        const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
        const request: authentication.CancelAuthorizationRequest =
          provider.createCancelAuthorizationRequest();
        const controller: authentication.AuthenticationController =
          new authentication.AuthenticationController(AccountService.context);
        await controller.executeRequest(request);
      } catch (_) {
        // 即使远端撤销失败，也清理本地展示资料并回到游客模式。
      }
    }
    AccountService.profile = new AccountProfile();
    await StorageService.clearCachedAccount();
    return AccountService.getProfile();
  }

  private static fail(message: string): AccountProfile {
    AccountService.profile.status = AccountStatus.ERROR;
    AccountService.profile.name = '玩家';
    AccountService.profile.avatar = '';
    AccountService.profile.message = message;
    return AccountService.getProfile();
  }
}
