/**
 * 设置 — 主题切换 + 分类管理（新增/编辑/删除）
 */
import { DataStore } from '../model/DataStore';
import { Category, TxType, genId, CATEGORY_COLORS } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
import { pickAndSaveWallpaper, getWallpaperPath, removeWallpaper, GLASS_BLUR_MIN, GLASS_BLUR_MAX } from '../common/GlassKit';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

const store = DataStore.getInstance();

interface PickerState {
  visible: boolean;
  editing: Category | null;
  isExpense: boolean;
  name: string;
  icon: string;
  color: string;
}

@Entry
@Component
struct Settings {
  @State themeName: string = 'dark';
  @State theme: ThemeColors = DARK_THEME;

  @State cats: Category[] = [];
  @State picker: PickerState = {
    visible: false,
    editing: null,
    isExpense: true,
    name: '',
    icon: '📌',
    color: CATEGORY_COLORS[0]
  };

  // 玻璃主题状态
  @State glassEnabled: boolean = false;
  @State glassBlur: number = 30;
  @State hasWallpaper: boolean = false;
  @State wallpaperPath: string = '';

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[Settings] store init failed: ${JSON.stringify(e)}`);
    }
    const saved = await store.getTheme();
    this.themeName = saved;
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(saved) : getTheme(saved);
    this.hasWallpaper = (await getWallpaperPath(this.getUIContext().getHostContext()!)).length > 0;
    this.cats = await store.getCategories();
  }

  // 切换玻璃模式
  async toggleGlass(on: boolean): Promise<void> {
    this.glassEnabled = on;
    await store.saveGlassEnabled(on);
    if (on && !this.hasWallpaper) {
      promptAction.showToast({ message: '请先选择一张壁纸照片' });
    }
  }

  // 选择壁纸
  async pickWallpaper(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (!ctx) return;
    promptAction.showToast({ message: '正在打开相册...' });
    console.info(`[Glass] pickWallpaper start`);
    const path = await pickAndSaveWallpaper(ctx);
    console.info(`[Glass] pickWallpaper path='${path}'`);
    if (path.length > 0) {
      this.hasWallpaper = true;
      this.glassEnabled = true;
      await store.saveGlassEnabled(true);
      console.info(`[Glass] saveGlassEnabled(true) done`);
      promptAction.showToast({ message: '壁纸已设置 ✓' });
    } else {
      console.info(`[Glass] path empty, skip save`);
      promptAction.showToast({ message: '未选择照片' });
    }
  }

  // 移除壁纸
  async removeWallpaper(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (!ctx) return;
    await removeWallpaper(ctx);
    this.hasWallpaper = false;
    this.glassEnabled = false;
    await store.saveGlassEnabled(false);
    promptAction.showToast({ message: '已移除壁纸' });
  }

  // 调节模糊度
  async onBlurChange(v: number): Promise<void> {
    this.glassBlur = v;
    await store.saveGlassBlur(v);
  }

  toggleTheme(): void {
    const next = this.themeName === 'dark' ? 'light' : 'dark';
    this.themeName = next;
    this.theme = getTheme(next);
    store.saveTheme(next);
  }

  openAdd(isExpense: boolean): void {
    this.picker = {
      visible: true,
      editing: null,
      isExpense: isExpense,
      name: '',
      icon: '📌',
      color: CATEGORY_COLORS[0]
    };
  }

  openEdit(cat: Category): void {
    this.picker = {
      visible: true,
      editing: cat,
      isExpense: cat.type === TxType.Expense,
      name: cat.name,
      icon: cat.icon,
      color: cat.color
    };
  }

  closePicker(): void {
    this.picker = {
      visible: false,
      editing: null,
      isExpense: true,
      name: '',
      icon: '📌',
      color: CATEGORY_COLORS[0]
    };
  }

  async savePicker(): Promise<void> {
    const name = this.picker.name.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入分类名称' });
      return;
    }
    if (this.picker.editing) {
      const updated: Category = {
        id: this.picker.editing.id,
        name: name,
        icon: this.picker.icon,
        color: this.picker.color,
        type: this.picker.editing.type,
        isDefault: this.picker.editing.isDefault
      };
      await store.saveCategory(updated);
    } else {
      const cat: Category = {
        id: genId(),
        name: name,
        icon: this.picker.icon,
        color: this.picker.color,
        type: this.picker.isExpense ? TxType.Expense : TxType.Income,
        isDefault: false
      };
      await store.saveCategory(cat);
    }
    this.closePicker();
    this.load();
    promptAction.showToast({ message: '分类已保存' });
  }

  deleteCat(cat: Category): void {
    if (cat.isDefault) {
      promptAction.showToast({ message: '默认分类不可删除' });
      return;
    }
    promptAction.showDialog({
      title: '删除分类',
      message: `确定删除「${cat.name}」吗？`,
      buttons: [
        { text: '取消', color: this.theme.textSecondary },
        { text: '删除', color: this.theme.danger }
      ]
    }).then((res) => {
      if (res.index === 1) {
        store.deleteCategory(cat.id).then(() => {
          this.cats = this.cats.filter(c => c.id !== cat.id);
          promptAction.showToast({ message: '分类已删除' });
        });
      }
    }).catch(() => {});
  }

  @Builder
  pickerContent() {
    Column() {
      // 顶部把手
      Row()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor(this.theme.border)
        .margin({ bottom: 16 })

      Text(this.picker.editing ? '编辑分类' : '新增分类')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.textPrimary)
        .margin({ bottom: 20 })

      // 类型（新增时可选）
      if (!this.picker.editing) {
        Row() {
          Text('支出')
            .fontSize(14)
            .fontWeight(this.picker.isExpense ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.picker.isExpense ? Color.White : this.theme.textSecondary)
            .textAlign(TextAlign.Center)
            .height(38)
            .layoutWeight(1)
            .backgroundColor(this.picker.isExpense ? this.theme.accent : Color.Transparent)
            .borderRadius(9)
            .onClick(() => {
              this.picker.isExpense = true;
            })

          Text('收入')
            .fontSize(14)
            .fontWeight(!this.picker.isExpense ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(!this.picker.isExpense ? Color.White : this.theme.textSecondary)
            .textAlign(TextAlign.Center)
            .height(38)
            .layoutWeight(1)
            .backgroundColor(!this.picker.isExpense ? this.theme.accent : Color.Transparent)
            .borderRadius(9)
            .onClick(() => {
              this.picker.isExpense = false;
            })
        }
        .width('100%')
        .backgroundColor(this.theme.bgElevated)
        .borderRadius(12)
        .padding(3)
        .margin({ bottom: 16 })
      }

      // 名称
      Row() {
        Text('名称')
          .fontSize(14)
          .fontColor(this.theme.textSecondary)
          .width(56)
        TextInput({ placeholder: '分类名称', text: this.picker.name })
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textMuted)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onChange((v: string) => {
            this.picker.name = v;
          })
      }
      .width('100%')
      .border({ width: { bottom: 1 }, color: this.theme.borderLight })
      .padding({ top: 10, bottom: 10 })

      // 图标
      Row() {
        Text('图标')
          .fontSize(14)
          .fontColor(this.theme.textSecondary)
          .width(56)
        TextInput({ placeholder: '输入 emoji，如 🍜', text: this.picker.icon })
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .placeholderColor(this.theme.textMuted)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .onChange((v: string) => {
            this.picker.icon = v;
          })
      }
      .width('100%')
      .border({ width: { bottom: 1 }, color: this.theme.borderLight })
      .padding({ top: 10, bottom: 10 })

      // 颜色
      Column() {
        Text('颜色')
          .fontSize(14)
          .fontColor(this.theme.textSecondary)
          .width('100%')
          .margin({ bottom: 10 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(CATEGORY_COLORS, (color: string) => {
            Row()
              .width(30)
              .height(30)
              .borderRadius(15)
              .backgroundColor(color)
              .border({
                width: this.picker.color === color ? 3 : 0,
                color: this.theme.textPrimary
              })
              .margin({ right: 8, bottom: 8 })
              .onClick(() => {
                this.picker.color = color;
              })
          }, (color: string) => color)
        }
        .width('100%')
      }
      .width('100%')
      .margin({ top: 16 })

      // 操作按钮
      Row() {
        Button('取消')
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .backgroundColor(this.theme.bgElevated)
          .borderRadius(12)
          .height(46)
          .layoutWeight(1)
          .onClick(() => this.closePicker())

        Blank().width(12)

        Button('保存')
          .fontSize(15)
          .fontColor(Color.White)
          .backgroundColor(this.theme.accent)
          .borderRadius(12)
          .height(46)
          .layoutWeight(2)
          .onClick(() => this.savePicker())
      }
      .width('100%')
      .margin({ top: 20 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, bottom: 24 })
    .backgroundColor(this.theme.bgCard)
    .borderRadius({ topLeft: 20, topRight: 20 })
  }

  build() {
    Stack() {
      // 玻璃壁纸背景
      GlassBackground({ wallpaperPath: this.wallpaperPath, blurRadius: this.glassBlur })
        .width('100%')
        .height('100%')

    Column() {
      // 导航栏
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor(this.theme.textPrimary)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())

        Text('设置')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(40)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 6 })

      Scroll() {
        Column() {
          // ===== 外观 =====
          Column() {
            Row() {
              Text('深色模式')
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.themeName === 'dark' })
                .selectedColor(this.theme.accent)
                .onChange((isOn: boolean) => {
                  const next = isOn ? 'dark' : 'light';
                  this.themeName = next;
                  this.theme = getTheme(next);
                  store.saveTheme(next);
                })
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 玻璃主题 =====
          Column() {
            Row() {
              Column() {
                Text('玻璃主题')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                Text('照片壁纸 + 毛玻璃卡片')
                  .fontSize(11)
                  .fontColor(this.theme.textMuted)
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Toggle({ type: ToggleType.Switch, isOn: this.glassEnabled })
                .selectedColor(this.theme.accent)
                .onChange((isOn: boolean) => this.toggleGlass(isOn))
            }
            .width('100%')
            .margin({ bottom: 12 })

            // 模糊度滑块
            Column() {
              Row() {
                Text('模糊度')
                  .fontSize(13)
                  .fontColor(this.theme.textSecondary)
                  .layoutWeight(1)
                Text(`${Math.round(this.glassBlur)}`)
                  .fontSize(13)
                  .fontColor(this.theme.accent)
                  .fontWeight(FontWeight.Medium)
              }
              .width('100%')
              .margin({ bottom: 6 })

              Slider({
                value: this.glassBlur,
                min: GLASS_BLUR_MIN,
                max: GLASS_BLUR_MAX,
                step: 1
              })
                .selectedColor(this.theme.accent)
                .trackColor(this.theme.bgElevated)
                .blockColor(this.theme.accent)
                .onChange((v: number) => this.onBlurChange(v))
            }
            .width('100%')
            .margin({ bottom: 12 })

            // 壁纸操作
            Row() {
              Text('壁纸')
                .fontSize(13)
                .fontColor(this.theme.textSecondary)
                .layoutWeight(1)
              if (this.hasWallpaper) {
                Text('更换')
                  .fontSize(13)
                  .fontColor(this.theme.accent)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.theme.accentMuted)
                  .borderRadius(8)
                  .onClick(() => this.pickWallpaper())
                Text('移除')
                  .fontSize(13)
                  .fontColor(this.theme.danger)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.theme.expenseBg)
                  .borderRadius(8)
                  .margin({ left: 8 })
                  .onClick(() => this.removeWallpaper())
              } else {
                Text('选择照片')
                  .fontSize(13)
                  .fontColor(Color.White)
                  .padding({ left: 14, right: 14, top: 6, bottom: 6 })
                  .backgroundColor(this.theme.accent)
                  .borderRadius(8)
                  .onClick(() => this.pickWallpaper())
              }
            }
            .width('100%')
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 支出分类 =====
          Column() {
            Row() {
              Text('支出分类')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('+ 新增')
                .fontSize(13)
                .fontColor(this.theme.accent)
                .onClick(() => this.openAdd(true))
            }
            .width('100%')
            .margin({ bottom: 4 })

            ForEach(this.cats.filter(c => c.type === TxType.Expense), (cat: Category) => {
              Row() {
                Text(cat.icon)
                  .fontSize(18)
                  .width(38)
                  .height(38)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(cat.color + '22')
                  .borderRadius(9)

                Column() {
                  Text(cat.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                  Text(cat.isDefault ? '默认' : '自定义')
                    .fontSize(11)
                    .fontColor(this.theme.textMuted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })

                Text('✎')
                  .fontSize(15)
                  .fontColor(this.theme.textSecondary)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.openEdit(cat))

                Text('✕')
                  .fontSize(15)
                  .fontColor(this.theme.textMuted)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.deleteCat(cat))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (cat: Category) => cat.id)
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 收入分类 =====
          Column() {
            Row() {
              Text('收入分类')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('+ 新增')
                .fontSize(13)
                .fontColor(this.theme.accent)
                .onClick(() => this.openAdd(false))
            }
            .width('100%')
            .margin({ bottom: 4 })

            ForEach(this.cats.filter(c => c.type === TxType.Income), (cat: Category) => {
              Row() {
                Text(cat.icon)
                  .fontSize(18)
                  .width(38)
                  .height(38)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(cat.color + '22')
                  .borderRadius(9)

                Column() {
                  Text(cat.name)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                  Text(cat.isDefault ? '默认' : '自定义')
                    .fontSize(11)
                    .fontColor(this.theme.textMuted)
                    .margin({ top: 2 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                .margin({ left: 12 })

                Text('✎')
                  .fontSize(15)
                  .fontColor(this.theme.textSecondary)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.openEdit(cat))

                Text('✕')
                  .fontSize(15)
                  .fontColor(this.theme.textMuted)
                  .width(34)
                  .height(34)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.deleteCat(cat))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (cat: Category) => cat.id)
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          Text('记账 v1.0.0 · 数据存储于本地')
            .fontSize(11)
            .fontColor(this.theme.textMuted)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 20 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // ===== 分类编辑底部弹窗 =====
      if (this.picker.visible) {
        Stack() {
          // 遮罩
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.6)')
            .onClick(() => this.closePicker())

          // 底部面板
          Column() {
            this.pickerContent()
          }
          .width('100%')
          .align(Alignment.Bottom)
        }
        .width('100%')
        .height('100%')
      }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.glassEnabled ? 'rgba(0,0,0,0)' : this.theme.bgPrimary)
    }
    .width('100%')
    .height('100%')
  }
}
