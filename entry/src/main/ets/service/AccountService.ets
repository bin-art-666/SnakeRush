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
  private static requestInProgress: boolean = false;

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
    if (AccountService.requestInProgress) {
      const pending: AccountProfile = AccountService.getProfile();
      pending.status = AccountStatus.AUTHORIZING;
      pending.message = '登录请求正在处理中';
      return pending;
    }
    AccountService.requestInProgress = true;
    AccountService.profile.status = AccountStatus.AUTHORIZING;
    AccountService.profile.message = '';
    try {
      const provider: authentication.HuaweiIDProvider = new authentication.HuaweiIDProvider();
      const request: authentication.AuthorizationWithHuaweiIDRequest =
        provider.createAuthorizationWithHuaweiIDRequest();
      // 只请求头像和昵称，不请求手机号、邮箱、授权码或令牌。
      request.scopes = ['profile'];
      // 必须为 true：未登录或未授权时由 Account Kit 主动拉起登录/授权页面。
      request.forceAuthorization = true;
      const controller: authentication.AuthenticationController =
        new authentication.AuthenticationController(AccountService.context);
      const response: authentication.AuthenticationResponse = await controller.executeRequest(request);
      const authResponse: authentication.AuthorizationWithHuaweiIDResponse =
        response as authentication.AuthorizationWithHuaweiIDResponse;
      const credential: authentication.AuthorizationWithHuaweiIDCredential | undefined = authResponse.data;
      if (credential === undefined) {
        return AccountService.fail('未获取到账号资料');
      }
      const authorizedScopes: string[] = credential.authorizedScopes ?? [];
      if (authorizedScopes.indexOf('profile') < 0) {
        return AccountService.fail('未授权昵称与头像权限，请重新登录并允许资料授权');
      }
      AccountService.profile.status = AccountStatus.SIGNED_IN;
      AccountService.profile.name = credential.nickName ?? '华为用户';
      AccountService.profile.avatar = credential.avatarUri ?? '';
      AccountService.profile.message = '登录成功';
      await StorageService.saveCachedAccount(AccountService.profile.name, AccountService.profile.avatar);
      return AccountService.getProfile();
    } catch (error) {
      const businessError: BusinessError = error as BusinessError;
      return AccountService.handleError(businessError);
    } finally {
      AccountService.requestInProgress = false;
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

  private static handleError(error: BusinessError): AccountProfile {
    const code: number = error.code;
    switch (code) {
      case authentication.AuthenticationErrorCode.USER_CANCELED:
        AccountService.profile = new AccountProfile();
        AccountService.profile.message = '已取消登录';
        return AccountService.getProfile();
      case authentication.AuthenticationErrorCode.PACKAGE_FINGERPRINT_CHECK_ERROR:
        return AccountService.fail('应用签名校验失败，请检查 AGC 中的包名和证书指纹（1001500001）');
      case authentication.AuthenticationErrorCode.DUPLICATE_REQUEST_REJECTED:
        return AccountService.fail('登录请求正在处理中，请勿重复点击（1001500002）');
      case authentication.AuthenticationErrorCode.SCOPE_OR_PERRMISSION_UNSUPPORTED:
        return AccountService.fail('当前应用不支持 profile 权限，请检查 Account Kit 配置（1001500003）');
      case authentication.AuthenticationErrorCode.ACCOUNT_NOT_LOGGED_IN:
        return AccountService.fail('设备尚未登录华为账号（1001502001）');
      case authentication.AuthenticationErrorCode.APP_NOT_AUTHORIZED:
        return AccountService.fail('应用尚未获得华为账号授权（1001502002）');
      case authentication.AuthenticationErrorCode.PARAMETER_INVALID:
        return AccountService.fail('华为账号请求参数无效（1001502003）');
      case authentication.AuthenticationErrorCode.NETWORK_ERROR:
        return AccountService.fail('网络异常，请检查网络后重试（1001502005）');
      case authentication.AuthenticationErrorCode.INTERNAL_ERROR:
        return AccountService.fail('华为账号服务暂时异常（1001502009）');
      case authentication.AuthenticationErrorCode.SCOPE_OR_PERMISSION_NOT_REQUESTED:
        return AccountService.fail('Account Kit 权限尚未开通或审核通过（1001502014）');
      case 401:
        return AccountService.fail('华为账号请求参数错误（401）');
      case 801:
        return AccountService.fail('当前设备不支持华为账号能力（801）');
      default:
        return AccountService.fail('登录失败，错误码：' + code.toString());
    }
  }
}
