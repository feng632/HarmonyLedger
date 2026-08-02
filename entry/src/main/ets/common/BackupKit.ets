/**
 * 数据备份工具 — 导出/恢复 JSON 备份文件
 * 使用系统文件选择器让用户选择保存/打开位置（免权限）
 */
import { picker, fileIo as fs } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { common } from '@kit.AbilityKit';
import { DataStore } from '../model/DataStore';

const store = DataStore.getInstance();

/**
 * 导出备份：弹出系统保存对话框，把数据写入用户选择的文件
 */
export async function exportBackup(context: common.Context): Promise<string> {
  try {
    const json = await store.exportAll();
    const docPicker = new picker.DocumentViewPicker();
    const saveUri = await docPicker.save({
      newFileNames: [`记账备份_${formatDateForName()}.json`]
    });
    if (saveUri.length === 0) {
      return '';
    }
    // 写入文件
    const file = fs.openSync(saveUri[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    fs.writeSync(file.fd, json);
    fs.closeSync(file);
    return saveUri[0];
  } catch (e) {
    console.error(`[Backup] export failed: ${JSON.stringify(e)}`);
    return '';
  }
}

/**
 * 恢复备份：弹出系统文件选择器，读取 JSON 并覆盖数据
 */
export async function importBackup(context: common.Context): Promise<boolean> {
  try {
    const docPicker = new picker.DocumentViewPicker();
    const result = await docPicker.select({
      fileSuffixFilters: ['.json']
    });
    if (result.length === 0) {
      return false;
    }
    const file = fs.openSync(result[0], fs.OpenMode.READ_ONLY);
    const stat = fs.statSync(file.fd);
    const buf = new ArrayBuffer(stat.size);
    fs.readSync(file.fd, buf);
    fs.closeSync(file);
    // UTF-8 解码（ArkTS 不支持 fromCharCode.apply）
    const decoder = util.TextDecoder.create('utf-8');
    const json = decoder.decodeToString(new Uint8Array(buf));
    return await store.importAll(json);
  } catch (e) {
    console.error(`[Backup] import failed: ${JSON.stringify(e)}`);
    return false;
  }
}

function formatDateForName(): string {
  const d = new Date();
  const pad = (n: number) => n < 10 ? '0' + n.toString() : n.toString();
  return `${d.getFullYear()}${pad(d.getMonth() + 1)}${pad(d.getDate())}_${pad(d.getHours())}${pad(d.getMinutes())}`;
}
