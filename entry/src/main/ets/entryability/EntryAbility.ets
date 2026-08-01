import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { DataStore } from '../model/DataStore';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'Ability onWindowStageCreate');

    // 预先初始化全局主题键，避免 @StorageLink 首帧 undefined
    AppStorage.setOrCreate('themeName', 'dark');

    // 初始化数据存储，并加载已保存主题
    DataStore.getInstance().init(this.context).then(() => {
      hilog.info(0x0000, TAG, 'DataStore initialized');
      return DataStore.getInstance().getTheme();
    }).then((saved: string) => {
      AppStorage.setOrCreate('themeName', saved);
      hilog.info(0x0000, TAG, `Theme applied: ${saved}`);
    }).catch((e: BusinessError) => {
      hilog.error(0x0000, TAG, `DataStore init failed: ${JSON.stringify(e)}`);
    });

    windowStage.loadContent('pages/Index', (err: BusinessError) => {
      if (err.code) {
        hilog.error(0x0000, TAG, `Failed to load content: ${err.message}`);
        return;
      }
      hilog.info(0x0000, TAG, 'Content loaded');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, 'Ability onBackground');
  }
}
