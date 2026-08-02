/**
 * 玻璃背景组件 — 全屏壁纸照片 + 全局玻璃状态
 * 挂在每个页面根 Stack 的最底层
 */
import { getWallpaperPath } from './GlassKit';
import { DataStore } from '../model/DataStore';
import { common } from '@kit.AbilityKit';

const store = DataStore.getInstance();

@Component
export struct GlassBackground {
  // 壁纸图片路径（空 = 无壁纸，隐藏背景）
  @Prop wallpaperPath: string = '';
  // 玻璃模糊度
  @Prop blurRadius: number = 30;

  build() {
    if (this.wallpaperPath.length > 0) {
      Image(this.wallpaperPath)
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .blur(this.blurRadius)
        .position({ x: 0, y: 0 })
    } else {
      Blank()
        .width('100%')
        .height('100%')
    }
  }
}

/**
 * 读取全局玻璃状态（壁纸路径 + 模糊度）
 * 用于页面 aboutToAppear 时加载
 */
export async function loadGlassState(hostContext: common.Context | undefined): Promise<GlassState> {
  const state: GlassState = { enabled: false, blur: 30, wallpaperPath: '' };
  if (!hostContext) return state;
  try {
    state.enabled = await store.getGlassEnabled();
    state.blur = await store.getGlassBlur();
    if (state.enabled) {
      state.wallpaperPath = await getWallpaperPath(hostContext);
    }
  } catch (e) {
    console.error(`[Glass] load state failed: ${JSON.stringify(e)}`);
  }
  return state;
}

export interface GlassState {
  enabled: boolean;
  blur: number;
  wallpaperPath: string;
}
