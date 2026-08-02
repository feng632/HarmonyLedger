/**
 * 桌面小组件 — 月度余额卡片
 * 读取 App 写好的汇总 JSON 文件（/data/storage/el2/base/files/monthly_summary.json）
 */
import { FormExtensionAbility, formBindingData, formProvider } from '@kit.FormKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Want } from '@kit.AbilityKit';

export default class FormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    console.info(`[Form] onAddForm`);
    // 获取本次添加的 formId，异步填充真实数据
    const formId = want.parameters ? want.parameters['ohos.extra.param.key.form_id'] as string : '';
    if (formId) {
      this.asyncRefresh(formId);
    }
    return this.buildCardData();
  }

  onUpdateForm(formId: string): void {
    console.info(`[Form] onUpdateForm: ${formId}`);
    this.asyncRefresh(formId);
  }

  // 异步读取汇总文件并推送真实数据
  async asyncRefresh(formId: string): Promise<void> {
    try {
      const data = this.buildCardData();
      await formProvider.updateForm(formId, data);
      console.info(`[Form] updated: ${formId}`);
    } catch (e) {
      console.error(`[Form] asyncRefresh failed: ${JSON.stringify(e)}`);
    }
  }

  // 读取汇总文件构建卡片数据
  buildCardData(): formBindingData.FormBindingData {
    try {
      const path = `${this.context.filesDir}/monthly_summary.json`;
      let summary: SummaryData = { monthLabel: '', income: '--', expense: '--', balance: '--' };
      try {
        const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
        const stat = fs.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fs.readSync(file.fd, buf);
        fs.closeSync(file);
        const json = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
        summary = JSON.parse(json) as SummaryData;
      } catch (e) {
        // 文件不存在时用占位
      }
      const obj: Record<string, Object> = {
        'monthLabel': summary.monthLabel,
        'balance': summary.balance,
        'income': summary.income,
        'expense': summary.expense
      };
      return formBindingData.createFormBindingData(obj);
    } catch (e) {
      console.error(`[Form] build data failed: ${JSON.stringify(e)}`);
      return formBindingData.createFormBindingData({
        'monthLabel': '',
        'balance': '--',
        'income': '--',
        'expense': '--'
      });
    }
  }
}

interface SummaryData {
  monthLabel: string;
  income: string;
  expense: string;
  balance: string;
}
