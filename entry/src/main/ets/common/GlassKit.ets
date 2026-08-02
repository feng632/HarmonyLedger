/**
 * 玻璃模式工具 — 照片壁纸选择/持久化 + 全局玻璃状态
 */
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DataStore } from '../model/DataStore';

const store = DataStore.getInstance();

export const GLASS_BLUR_MIN = 10;
export const GLASS_BLUR_MAX = 60;
export const GLASS_BLUR_DEFAULT = 30;

/**
 * 从系统相册选择一张照片，拷贝到应用沙箱持久保存
 * @returns 沙箱内壁纸文件路径（失败返回空字符串）
 */
export async function pickAndSaveWallpaper(context: common.Context): Promise<string> {
  try {
    const picker = new photoAccessHelper.PhotoViewPicker();
    const result = await picker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: 1
    });
    if (result.photoUris.length === 0) {
      return '';
    }
    const srcUri = result.photoUris[0];

    // 拷贝到应用沙箱 files 目录（持久保存，避免相册 URI 失效）
    const filesDir = context.filesDir;
    const fileName = `wallpaper_${Date.now().toString(36)}.jpg`;
    const destPath = `${filesDir}/${fileName}`;

    try {
      await fs.copyFile(srcUri, destPath);
    } catch (e) {
      // copyFile 可能不支持 media URI，回退：先 open 再 copy
      console.error(`[Glass] copyFile failed: ${JSON.stringify(e)}`);
      const srcFile = fs.openSync(srcUri, fs.OpenMode.READ_ONLY);
      const destFile = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
      const stat = fs.statSync(srcFile.fd);
      const buf = new ArrayBuffer(stat.size);
      fs.readSync(srcFile.fd, buf);
      fs.writeSync(destFile.fd, buf);
      fs.closeSync(srcFile);
      fs.closeSync(destFile);
    }

    // 删除旧壁纸文件
    const oldFile = await store.getWallpaperFile();
    if (oldFile) {
      try {
        fs.unlinkSync(`${filesDir}/${oldFile}`);
      } catch (e) {
        // 旧文件不存在忽略
      }
    }

    await store.saveWallpaperFile(fileName);
    return destPath;
  } catch (e) {
    console.error(`[Glass] pick failed: ${JSON.stringify(e)}`);
    return '';
  }
}

/**
 * 获取当前壁纸完整路径（不存在返回空串）
 */
export async function getWallpaperPath(context: common.Context): Promise<string> {
  const fileName = await store.getWallpaperFile();
  if (!fileName) return '';
  const path = `${context.filesDir}/${fileName}`;
  try {
    fs.accessSync(path);
    return path;
  } catch (e) {
    return '';
  }
}

/**
 * 移除壁纸
 */
export async function removeWallpaper(context: common.Context): Promise<void> {
  const fileName = await store.getWallpaperFile();
  if (fileName) {
    try {
      fs.unlinkSync(`${context.filesDir}/${fileName}`);
    } catch (e) {
      // 忽略
    }
    await store.saveWallpaperFile('');
  }
}
