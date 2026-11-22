import { bundleManager, common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { i18n } from '@kit.LocalizationKit';

export class EnvironmentInfo {
  isDebug: boolean;
  osName: string;
  osVersion: string;
  locale: string;
  appVersion: string;
  appBuildNumber: string;
  deviceModel: string;

  constructor(
    isDebug: boolean = false,
    osName: string = '',
    osVersion: string = '',
    locale: string = '',
    appVersion: string = '',
    appBuildNumber: string = '',
    deviceModel: string = '',
  ) {
    this.isDebug = isDebug;
    this.osName = osName;
    this.osVersion = osVersion;
    this.locale = locale;
    this.appVersion = appVersion;
    this.appBuildNumber = appBuildNumber;
    this.deviceModel = deviceModel;
  }

  static get(context: common.Context): EnvironmentInfo {
    const bundle = bundleManager.getBundleInfoForSelfSync(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT);
    const language = i18n.System.getAppPreferredLanguage() || i18n.System.getSystemLanguage();
    return new EnvironmentInfo(
      context.applicationInfo.debug,
      'HarmonyOS',
      deviceInfo.distributionOSApiName || deviceInfo.distributionOSVersion ||
        `${deviceInfo.majorVersion}.${deviceInfo.seniorVersion}.${deviceInfo.featureVersion}`,
      language.split(/[-_]/)[0].toLowerCase(),
      bundle.versionName,
      bundle.versionCode.toString(),
      deviceInfo.productModel,
    );
  }
}
