/**
 * 记一笔 — 支出/收入录入（自定义数字键盘，Row 布局保证可点击）
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, Template, TxType, DateUtil, genId } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
import { checkAndNotifyBudget } from '../common/BudgetAlert';
import { SpeechRecognizer, parseSpeech, SpeechCategory } from '../common/SpeechKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';

const store = DataStore.getInstance();

@Entry
@Component
struct AddRecord {
  @State theme: ThemeColors = DARK_THEME;
  @State themeName: string = 'dark';

  @State isExpense: boolean = true;
  @State cats: Category[] = [];
  @State selectedCatId: string = '';
  @State selectedCatName: string = '';
  @State amountStr: string = '';
  @State displayAmount: string = '0.00';
  @State note: string = '';
  @State dateStr: string = DateUtil.today();

  // 玻璃模式状态
  @State glassEnabled: boolean = false;
  @State glassBlur: number = 30;
  @State wallpaperPath: string = '';

  // 记账模板
  @State templates: Template[] = [];
  @State allCats: Category[] = [];
  // 语音记账
  @State isListening: boolean = false;
  private recognizer: SpeechRecognizer | null = null;
  // 模板编辑弹窗状态
  @State tplEditorVisible: boolean = false;
  @State tplEditorIsNew: boolean = true;
  @State tplEditorId: string = '';
  @State tplEditorName: string = '';
  @State tplEditorIcon: string = '📌';
  @State tplEditorAmount: string = '';
  @State tplEditorCatId: string = '';

  // 数字键盘布局（4 行 × 3 列）
  private keys: string[][] = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['.', '0', '⌫']
  ];

  // 计算当前金额（普通方法，避免 getter this 绑定问题）
  calcAmount(): number {
    if (this.amountStr === '') return 0;
    const v = parseFloat(this.amountStr);
    if (isNaN(v)) return 0;
    return Math.round(v * 100) / 100;
  }

  aboutToAppear(): void {
    this.loadCats();
  }

  async loadCats(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[AddRecord] store init failed: ${JSON.stringify(e)}`);
    }
    const savedTheme = await store.getTheme();
    this.themeName = savedTheme;
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(savedTheme) : getTheme(savedTheme);
    this.allCats = await store.getCategories();
    this.templates = await store.getTemplates();
    const all = this.allCats;
    this.cats = all.filter(c => c.type === (this.isExpense ? TxType.Expense : TxType.Income));
    if (this.selectedCatId === '' && this.cats.length > 0) {
      this.selectedCatId = this.cats[0].id;
    }
  }

  switchType(expense: boolean): void {
    if (this.isExpense === expense) return;
    this.isExpense = expense;
    this.selectedCatId = '';
    this.selectedCatName = '';
    this.amountStr = '';
    this.updateDisplayAmount();
    this.loadCats();
  }

  // 更新金额显示（自动补全两位小数）
  updateDisplayAmount(): void {
    if (this.amountStr === '') {
      this.displayAmount = '0.00';
      return;
    }
    const parts = this.amountStr.split('.');
    if (parts.length === 1) {
      this.displayAmount = this.amountStr + '.00';
      return;
    }
    const pad = 2 - parts[1].length;
    this.displayAmount = pad > 0 ? this.amountStr + '0'.repeat(pad) : this.amountStr;
  }

  // 数字键盘输入
  inputDigit(d: string): void {
    let val = this.amountStr;
    if (d === '.' && val.includes('.')) return;
    if (val.includes('.') && val.split('.')[1].length >= 2) return;
    if (d !== '.' && val.replace('.', '').length >= 8) return;
    this.amountStr = val + d;
    this.updateDisplayAmount();
    this.haptic();
  }

  inputDel(): void {
    this.amountStr = this.amountStr.slice(0, -1);
    this.updateDisplayAmount();
    this.haptic();
  }

  haptic(): void {
    try {
      vibrator.startVibration({ type: 'time', duration: 12 }, { usage: 'physicalFeedback' })
        .catch((e: BusinessError) => {});
    } catch (e) {
      // 震动失败忽略
    }
  }

  showDatePicker(): void {
    const parts = this.dateStr.split('-');
    const initial = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
    DatePickerDialog.show({
      start: new Date(2020, 0, 1),
      end: new Date(2035, 11, 31),
      selected: initial,
      onDateAccept: (value: Date) => {
        this.dateStr = DateUtil.formatDate(value.getFullYear(), value.getMonth() + 1, value.getDate());
      }
    });
  }

  async save(): Promise<void> {
    const amt = this.calcAmount();
    if (amt <= 0) {
      promptAction.showToast({ message: '请输入金额' });
      return;
    }
    if (this.selectedCatId === '') {
      promptAction.showToast({ message: '请选择分类' });
      return;
    }
    const tx: Transaction = {
      id: genId(),
      type: this.isExpense ? TxType.Expense : TxType.Income,
      amount: amt,
      categoryId: this.selectedCatId,
      note: this.note,
      date: this.dateStr,
      createdAt: Date.now()
    };
    await store.addTransaction(tx);
    // 检查预算超支并发送通知
    const ctx = this.getUIContext().getHostContext();
    if (ctx) {
      checkAndNotifyBudget(ctx);
    }
    promptAction.showToast({ message: this.isExpense ? '支出已记录' : '收入已记录' });
    router.back();
  }

  // ===== 模板功能 =====

  // 点击模板：一键填充表单
  applyTemplate(tpl: Template): void {
    this.isExpense = tpl.isExpense;
    this.selectedCatId = tpl.categoryId;
    this.selectedCatName = this.catNameById(tpl.categoryId);
    if (tpl.amount > 0) {
      this.amountStr = tpl.amount.toString();
      this.updateDisplayAmount();
    }
    this.note = tpl.note;
    this.haptic();
    promptAction.showToast({ message: `已填入「${tpl.name}」` });
  }

  catNameById(catId: string): string {
    const cat = this.allCats.find(c => c.id === catId);
    return cat ? cat.name : '';
  }

  // 长按模板：编辑/删除菜单
  manageTemplate(tpl: Template): void {
    promptAction.showActionMenu({
      title: tpl.name,
      buttons: [
        { text: '编辑', color: this.theme.accent },
        { text: '删除', color: this.theme.danger }
      ]
    }).then((res) => {
      if (res.index === 0) {
        this.openTplEditor(tpl);
      } else if (res.index === 1) {
        this.deleteTemplate(tpl.id);
      }
    }).catch(() => {});
  }

  async deleteTemplate(id: string): Promise<void> {
    await store.deleteTemplate(id);
    this.templates = await store.getTemplates();
    promptAction.showToast({ message: '模板已删除' });
  }

  // 打开模板编辑器（新增或编辑）
  openTplEditor(tpl: Template | null): void {
    if (tpl) {
      this.tplEditorIsNew = false;
      this.tplEditorId = tpl.id;
      this.tplEditorName = tpl.name;
      this.tplEditorIcon = tpl.icon;
      this.tplEditorAmount = tpl.amount > 0 ? tpl.amount.toString() : '';
      this.tplEditorCatId = tpl.categoryId;
    } else {
      this.tplEditorIsNew = true;
      this.tplEditorId = '';
      this.tplEditorName = '';
      this.tplEditorIcon = '📌';
      this.tplEditorAmount = '';
      // 默认选中当前分类
      this.tplEditorCatId = this.selectedCatId || (this.cats.length > 0 ? this.cats[0].id : '');
    }
    this.tplEditorVisible = true;
  }

  closeTplEditor(): void {
    this.tplEditorVisible = false;
  }

  // 保存模板
  async saveTplEditor(): Promise<void> {
    const name = this.tplEditorName.trim();
    if (name.length === 0) {
      promptAction.showToast({ message: '请输入模板名称' });
      return;
    }
    if (this.tplEditorCatId === '') {
      promptAction.showToast({ message: '请选择分类' });
      return;
    }
    const amt = parseFloat(this.tplEditorAmount);
    const tpl: Template = {
      id: this.tplEditorIsNew ? genId() : this.tplEditorId,
      icon: this.tplEditorIcon.trim() || '📌',
      name: name,
      amount: isNaN(amt) || amt <= 0 ? 0 : Math.round(amt * 100) / 100,
      categoryId: this.tplEditorCatId,
      note: '',
      isExpense: this.isExpense
    };
    await store.saveTemplate(tpl);
    this.templates = await store.getTemplates();
    this.tplEditorVisible = false;
    promptAction.showToast({ message: '模板已保存' });
  }

  // ===== 语音记账 =====

  // 请求麦克风权限
  async requestMicPermission(): Promise<boolean> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (!ctx) return false;
      const atManager = abilityAccessCtrl.createAtManager();
      const result = await atManager.requestPermissionsFromUser(ctx, ['ohos.permission.MICROPHONE']);
      if (result.authResults.length > 0 && result.authResults[0] === 0) {
        return true;
      }
      return false;
    } catch (e) {
      console.error(`[Speech] permission failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  // 开始语音识别
  async startSpeech(): Promise<void> {
    if (this.isListening) return;
    // 1. 请求麦克风权限
    const granted = await this.requestMicPermission();
    if (!granted) {
      promptAction.showToast({ message: '需要麦克风权限才能语音记账' });
      return;
    }

    this.isListening = true;
    promptAction.showToast({ message: '请说话，如"早餐八块"' });

    if (!this.recognizer) {
      this.recognizer = new SpeechRecognizer();
    }
    await this.recognizer.start((text: string) => {
      this.isListening = false;
      if (text.length === 0) {
        promptAction.showToast({ message: '未听清，请重试' });
        return;
      }
      this.handleSpeechResult(text);
    });
  }

  // 处理识别结果：解析并填入表单
  handleSpeechResult(text: string): void {
    // 构造分类列表（ArkTS 不允许 map 返回对象字面量）
    const cats: SpeechCategory[] = [];
    for (const c of this.allCats) {
      const sc: SpeechCategory = { id: c.id, name: c.name, icon: c.icon };
      cats.push(sc);
    }
    const parsed = parseSpeech(text, cats);

    promptAction.showToast({ message: `识别：${text}` });

    // 填入金额
    if (parsed.amount > 0) {
      this.amountStr = parsed.amount.toString();
      this.updateDisplayAmount();
    }

    // 填入分类
    if (parsed.categoryId.length > 0) {
      this.selectedCatId = parsed.categoryId;
      this.selectedCatName = parsed.categoryName;
      // 切换分类列表显示
      const cat = this.allCats.find(c => c.id === parsed.categoryId);
      if (cat) {
        this.isExpense = cat.type === TxType.Expense;
      }
    } else {
      promptAction.showToast({ message: '未识别到分类，请手动选择' });
    }

    if (parsed.amount === 0) {
      promptAction.showToast({ message: '未识别到金额，请手动输入' });
    }
  }

  // 停止语音
  stopSpeech(): void {
    if (this.recognizer) {
      this.recognizer.shutdown();
      this.recognizer = null;
    }
    this.isListening = false;
  }

  @Builder
  keyButton(key: string) {
    Text(key)
      .fontSize(26)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.textPrimary)
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(50)
      .backgroundColor(this.theme.bgElevated)
      .borderRadius(10)
      .onClick(() => {
        if (key === '⌫') {
          this.inputDel();
        } else {
          this.inputDigit(key);
        }
      })
  }

  build() {
    Stack() {
      // 玻璃壁纸背景
      GlassBackground({ wallpaperPath: this.wallpaperPath, blurRadius: this.glassBlur })
        .width('100%')
        .height('100%')

    Column() {
      // ===== 导航栏 =====
      Row() {
        Text('‹')
          .fontSize(32)
          .fontColor(this.theme.textPrimary)
          .width(40)
          .height(40)
          .textAlign(TextAlign.Center)
          .onClick(() => router.back())

        Text(this.isExpense ? '记支出' : '记收入')
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
          // ===== 类型切换（支出 / 收入）=====
          Row() {
            Text('支出')
              .fontSize(14)
              .fontWeight(this.isExpense ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.isExpense ? Color.White : this.theme.textSecondary)
              .textAlign(TextAlign.Center)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(this.isExpense ? this.theme.accent : Color.Transparent)
              .borderRadius(10)
              .onClick(() => this.switchType(true))

            Text('收入')
              .fontSize(14)
              .fontWeight(!this.isExpense ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(!this.isExpense ? Color.White : this.theme.textSecondary)
              .textAlign(TextAlign.Center)
              .height(40)
              .layoutWeight(1)
              .backgroundColor(!this.isExpense ? this.theme.income : Color.Transparent)
              .borderRadius(10)
              .onClick(() => this.switchType(false))
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(14)
          .border({ width: 1, color: this.theme.border })
          .padding(4)

          // ===== 记账模板快捷卡 =====
          if (this.templates.length > 0 || true) {
            Column() {
              Row() {
                Text('快捷模板')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .layoutWeight(1)
                Text('+ 新建')
                  .fontSize(12)
                  .fontColor(this.theme.accent)
                  .onClick(() => this.openTplEditor(null))
              }
              .width('100%')
              .margin({ bottom: 8 })

              // 模板卡片横滑
              Scroll() {
                Row() {
                  ForEach(this.templates, (tpl: Template) => {
                    Column() {
                      Text(tpl.icon)
                        .fontSize(20)
                        .width(44)
                        .height(44)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(this.theme.accentMuted)
                        .borderRadius(12)
                      Text(tpl.name)
                        .fontSize(11)
                        .fontColor(this.theme.textPrimary)
                        .fontWeight(FontWeight.Medium)
                        .margin({ top: 6 })
                        .maxLines(1)
                      Text(tpl.amount > 0 ? `¥${tpl.amount}` : '金额自定')
                        .fontSize(10)
                        .fontColor(this.theme.textSecondary)
                        .margin({ top: 2 })
                    }
                    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                    .backgroundColor(this.theme.bgCard)
                    .borderRadius(14)
                    .border({ width: 1, color: this.theme.border })
                    .margin({ right: 10 })
                    .onClick(() => this.applyTemplate(tpl))
                    .gesture(
                      LongPressGesture()
                        .onAction(() => this.manageTemplate(tpl))
                    )
                  }, (tpl: Template) => tpl.id)
                }
                .alignItems(VerticalAlign.Top)
              }
              .scrollable(ScrollDirection.Horizontal)
              .scrollBar(BarState.Off)
              .width('100%')
            }
            .width('100%')
            .margin({ top: 14, bottom: 4 })
          }

          // ===== 金额显示 + 语音按钮 =====
          Row() {
            // 语音记账按钮
            Column() {
              Text(this.isListening ? '🎤···' : '🎤')
                .fontSize(26)
                .width(52)
                .height(52)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.isListening ? this.theme.expenseBg : this.theme.accentMuted)
                .borderRadius(26)
                .onClick(() => {
                  if (this.isListening) {
                    this.stopSpeech();
                  } else {
                    this.startSpeech();
                  }
                })
              Text(this.isListening ? '聆听中' : '语音记账')
                .fontSize(9)
                .fontColor(this.theme.textSecondary)
                .margin({ top: 4 })
            }
            .width(64)
            .justifyContent(FlexAlign.Center)

            // 金额显示
            Column() {
              Text(this.isExpense ? '本月支出' : '本月收入')
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .letterSpacing(1)
              Text('¥ ' + this.displayAmount)
                .fontSize(46)
                .fontWeight(FontWeight.Lighter)
                .fontColor(this.amountStr === '' ? this.theme.textMuted : this.isExpense ? this.theme.textPrimary : this.theme.income)
                .fontFeature('tnum')
                .margin({ top: 8 })
            }
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ top: 18, bottom: 18, left: 16, right: 16 })
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(16)
          .border({ width: 1, color: this.theme.border })
          .margin({ top: 14, bottom: 14 })

          // ===== 分类 =====
          Column() {
            Row() {
              Text('分类')
                .fontSize(13)
                .fontColor(this.theme.textSecondary)
                .layoutWeight(1)
              Text('点击选择')
                .fontSize(11)
                .fontColor(this.theme.textMuted)
            }
            .width('100%')
            .margin({ bottom: 12 })

            Grid() {
              ForEach(this.cats, (cat: Category) => {
                GridItem() {
                  Column() {
                    Text(cat.icon)
                      .fontSize(22)
                      .width(46)
                      .height(46)
                      .textAlign(TextAlign.Center)
                      .backgroundColor(cat.color + '22')
                      .borderRadius(10)
                    Text(cat.name)
                      .fontSize(11)
                      .fontColor(this.selectedCatId === cat.id ? this.theme.accent : this.theme.textSecondary)
                      .fontWeight(this.selectedCatId === cat.id ? FontWeight.Medium : FontWeight.Regular)
                      .margin({ top: 6 })
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                  .border({
                    width: 1.5,
                    color: this.selectedCatId === cat.id ? this.theme.accent : Color.Transparent
                  })
                  .borderRadius(12)
                  .backgroundColor(this.selectedCatId === cat.id ? this.theme.accentMuted : Color.Transparent)
                  .onClick(() => {
                    this.selectedCatId = cat.id;
                    this.selectedCatName = cat.name;
                    this.haptic();
                  })
                }
              }, (cat: Category) => cat.id)
            }
            .columnsTemplate('1fr 1fr 1fr 1fr')
            .columnsGap(8)
            .rowsGap(8)
            .width('100%')
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 备注 + 日期 =====
          Row() {
            Column() {
              Text('备注')
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .width('100%')
              TextInput({ placeholder: '添加备注...', text: this.note })
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .placeholderColor(this.theme.textMuted)
                .placeholderFont({ size: 15 })
                .backgroundColor(Color.Transparent)
                .height(44)
                .onChange((v: string) => this.note = v)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Divider()
              .vertical(true)
              .height(40)
              .color(this.theme.border)
              .margin({ left: 12, right: 12 })

            Column() {
              Text('日期')
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .width('100%')
              Text(this.dateStr)
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .height(44)
                .onClick(() => this.showDatePicker())
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1.4)
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding({ left: 20, right: 20, top: 12, bottom: 12 })
          .margin({ bottom: 14 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      // ===== 保存按钮（固定，不被键盘遮挡）=====
      Button() {
        Text(this.isExpense ? '保存支出' : '保存收入')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .width('calc(100% - 32px)')
      .height(50)
      .backgroundColor(this.isExpense ? this.theme.accent : this.theme.income)
      .borderRadius(14)
      .shadow({ radius: 8, color: (this.isExpense ? this.theme.accent : this.theme.income) + '44', offsetY: 3 })
      .onClick(() => this.save())
      .margin({ bottom: 10 })

      // ===== 自定义数字键盘（Row 布局 + 按压缩放反馈）=====
      Column() {
        ForEach(this.keys, (row: string[]) => {
          Row() {
            ForEach(row, (key: string) => {
              Text(key)
                .fontSize(26)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .textAlign(TextAlign.Center)
                .width('33.3%')
                .height(52)
                .margin({ top: 5, bottom: 5, left: 4, right: 4 })
                .backgroundColor(this.theme.bgElevated)
                .borderRadius(12)
                .shadow({ radius: 6, color: 'rgba(0,0,0,0.18)', offsetY: 2 })
                .stateStyles({
                  pressed: {
                    .scale({ x: 0.92, y: 0.92 })
                    .backgroundColor(this.theme.border)
                  }
                })
                .onClick(() => {
                  if (key === '⌫') {
                    this.inputDel();
                  } else {
                    this.inputDigit(key);
                  }
                })
            }, (key: string) => key)
          }
          .width('100%')
        }, (row: string[]) => row[0])
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 6, bottom: 8 })
      .backgroundColor(this.theme.bgCard)
      .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
      .border({ width: { top: 1 }, color: this.theme.border })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.glassEnabled ? 'rgba(0,0,0,0)' : this.theme.bgPrimary)

      // ===== 模板编辑弹窗（渐变过渡动画）=====
      if (this.tplEditorVisible) {
        Stack() {
          // 遮罩：半透明黑 + 背景模糊（背后的界面渐进模糊）
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0,0,0,0.55)')
            .backdropBlur(12)
            .onClick(() => this.closeTplEditor())
            .transition(TransitionEffect.OPACITY.animation({ duration: 220, curve: Curve.EaseOut }))

          Column() {
            // 顶部把手
            Row()
              .width(36)
              .height(4)
              .borderRadius(2)
              .backgroundColor(this.theme.border)
              .margin({ bottom: 16 })

            Text(this.tplEditorIsNew ? '新建模板' : '编辑模板')
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .margin({ bottom: 20 })

            // 图标 + 名称
            Row() {
              Text('图标')
                .fontSize(14)
                .fontColor(this.theme.textSecondary)
                .width(56)
              TextInput({ placeholder: 'emoji，如 🍜', text: this.tplEditorIcon })
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .placeholderColor(this.theme.textMuted)
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .onChange((v: string) => this.tplEditorIcon = v)
            }
            .width('100%')
            .border({ width: { bottom: 1 }, color: this.theme.borderLight })
            .padding({ top: 10, bottom: 10 })

            Row() {
              Text('名称')
                .fontSize(14)
                .fontColor(this.theme.textSecondary)
                .width(56)
              TextInput({ placeholder: '如：早餐', text: this.tplEditorName })
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .placeholderColor(this.theme.textMuted)
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .onChange((v: string) => this.tplEditorName = v)
            }
            .width('100%')
            .border({ width: { bottom: 1 }, color: this.theme.borderLight })
            .padding({ top: 10, bottom: 10 })

            Row() {
              Text('金额')
                .fontSize(14)
                .fontColor(this.theme.textSecondary)
                .width(56)
              TextInput({ placeholder: '固定金额（留空=自定）', text: this.tplEditorAmount })
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .placeholderColor(this.theme.textMuted)
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .type(InputType.NUMBER_DECIMAL)
                .onChange((v: string) => this.tplEditorAmount = v)
            }
            .width('100%')
            .border({ width: { bottom: 1 }, color: this.theme.borderLight })
            .padding({ top: 10, bottom: 10 })

            // 分类选择
            Text('分类')
              .fontSize(14)
              .fontColor(this.theme.textSecondary)
              .width('100%')
              .margin({ top: 16, bottom: 8 })

            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.allCats.filter(c => c.type === (this.isExpense ? TxType.Expense : TxType.Income)), (cat: Category) => {
                Text(`${cat.icon} ${cat.name}`)
                  .fontSize(12)
                  .fontColor(this.tplEditorCatId === cat.id ? Color.White : this.theme.textSecondary)
                  .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                  .backgroundColor(this.tplEditorCatId === cat.id ? this.theme.accent : this.theme.bgElevated)
                  .borderRadius(16)
                  .margin({ right: 8, bottom: 8 })
                  .onClick(() => this.tplEditorCatId = cat.id)
              }, (cat: Category) => cat.id)
            }
            .width('100%')

            // 操作按钮
            Row() {
              Button('取消')
                .fontSize(15)
                .fontColor(this.theme.textPrimary)
                .backgroundColor(this.theme.bgElevated)
                .borderRadius(12)
                .height(46)
                .layoutWeight(1)
                .onClick(() => this.closeTplEditor())

              Blank().width(12)

              Button('保存')
                .fontSize(15)
                .fontColor(Color.White)
                .backgroundColor(this.theme.accent)
                .borderRadius(12)
                .height(46)
                .layoutWeight(2)
                .onClick(() => this.saveTplEditor())
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .width('100%')
          .padding({ left: 20, right: 20, bottom: 24 })
          // 弹窗始终用不透明深色背景，避免与下层界面重叠干扰
          .backgroundColor(this.themeName === 'light' ? '#FFFFFF' : '#262626')
          .borderRadius({ topLeft: 20, topRight: 20 })
          .align(Alignment.Bottom)
          .transition(
            TransitionEffect.asymmetric(
              TransitionEffect.move(TransitionEdge.BOTTOM)
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 260, curve: Curve.EaseOut }),
              TransitionEffect.move(TransitionEdge.BOTTOM)
                .combine(TransitionEffect.OPACITY)
                .animation({ duration: 200, curve: Curve.EaseIn })
            )
          )
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
