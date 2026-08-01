/**
 * 记一笔 — 支出/收入录入（自定义数字键盘，Row 布局保证可点击）
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, DateUtil, genId } from '../model/Models';
import { ThemeColors, getTheme, DARK_THEME } from '../common/Theme';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { vibrator } from '@kit.SensorServiceKit';

const store = DataStore.getInstance();

@Entry
@Component
struct AddRecord {
  @State theme: ThemeColors = DARK_THEME;

  @State isExpense: boolean = true;
  @State cats: Category[] = [];
  @State selectedCatId: string = '';
  @State selectedCatName: string = '';
  @State amountStr: string = '';
  @State displayAmount: string = '0.00';
  @State note: string = '';
  @State dateStr: string = DateUtil.today();

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
    this.theme = getTheme(await store.getTheme());
    const all = await store.getCategories();
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
    promptAction.showToast({ message: this.isExpense ? '支出已记录' : '收入已记录' });
    router.back();
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
          .borderRadius(14)
          .border({ width: 1, color: this.theme.border })
          .padding(4)

          // ===== 金额显示（带圆角卡底）=====
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
          .width('100%')
          .padding({ top: 18, bottom: 18 })
          .backgroundColor(this.theme.bgCard)
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
      .border({ width: { top: 1 }, color: this.theme.border })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgPrimary)
  }
}
