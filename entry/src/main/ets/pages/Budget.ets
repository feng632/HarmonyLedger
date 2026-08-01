/**
 * 预算 — 月度预算 + 分类管理
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, Budget } from '../model/Models';
import { ThemeColors, getTheme, fmtMoney, DARK_THEME } from '../common/Theme';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

const store = DataStore.getInstance();

@Entry
@Component
struct BudgetPage {
  @State theme: ThemeColors = DARK_THEME;

  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State budgetAmount: number = 0;
  @State spent: number = 0;
  @State budgetStr: string = '';
  @State cats: Category[] = [];

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[Budget] store init failed: ${JSON.stringify(e)}`);
    }
    this.theme = getTheme(await store.getTheme());
    this.cats = await store.getCategories();

    const budget = await store.getBudget(this.year, this.month);
    if (budget) {
      this.budgetAmount = budget.amount;
      this.budgetStr = budget.amount.toString();
    } else {
      this.budgetAmount = 0;
      this.budgetStr = '';
    }

    const txns = await store.getTransactionsByMonth(this.year, this.month);
    this.spent = txns
      .filter(t => t.type === TxType.Expense)
      .reduce((sum, t) => sum + t.amount, 0);
  }

  get pct(): number {
    if (this.budgetAmount <= 0) return 0;
    return Math.min(this.spent / this.budgetAmount * 100, 100);
  }

  get barColor(): string {
    if (this.pct >= 90) return this.theme.danger;
    if (this.pct >= 70) return this.theme.warning;
    return this.theme.accent;
  }

  async saveBudget(): Promise<void> {
    const amt = parseFloat(this.budgetStr);
    if (isNaN(amt) || amt <= 0) {
      promptAction.showToast({ message: '请输入有效预算金额' });
      return;
    }
    const budget: Budget = {
      id: `budget_${this.year}_${this.month}`,
      amount: Math.round(amt * 100) / 100,
      year: this.year,
      month: this.month
    };
    await store.saveBudget(budget);
    this.load();
    promptAction.showToast({ message: '预算已保存' });
  }

  deleteCat(id: string, isDefault: boolean): void {
    if (isDefault) {
      promptAction.showToast({ message: '默认分类不可删除' });
      return;
    }
    promptAction.showDialog({
      title: '删除分类',
      message: '确定删除这个分类吗？',
      buttons: [
        { text: '取消', color: this.theme.textSecondary },
        { text: '删除', color: this.theme.danger }
      ]
    }).then((res) => {
      if (res.index === 1) {
        store.deleteCategory(id).then(() => {
          this.cats = this.cats.filter(c => c.id !== id);
          promptAction.showToast({ message: '分类已删除' });
        });
      }
    }).catch(() => {});
  }

  build() {
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

        Text('预算')
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
          // ===== 月度预算 =====
          Column() {
            Text(`${this.year}年${this.month}月预算`)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .width('100%')
              .margin({ bottom: 16 })

            // 输入行
            Row() {
              Text('¥')
                .fontSize(20)
                .fontColor(this.theme.textPrimary)
              TextInput({ placeholder: '设置月度预算', text: this.budgetStr })
                .fontSize(20)
                .fontColor(this.theme.textPrimary)
                .placeholderColor(this.theme.textMuted)
                .backgroundColor(Color.Transparent)
                .layoutWeight(1)
                .type(InputType.NUMBER_DECIMAL)
                .margin({ left: 6, right: 12 })
                .onChange((v: string) => this.budgetStr = v)

              Text('保存')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .padding({ left: 16, right: 16, top: 8, bottom: 8 })
                .backgroundColor(this.theme.accent)
                .borderRadius(8)
                .onClick(() => this.saveBudget())
            }
            .width('100%')

            // 进度条
            if (this.budgetAmount > 0) {
              Column() {
                Stack({ alignContent: Alignment.Start }) {
                  Row()
                    .width('100%')
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.theme.bgElevated)
                  Row()
                    .width(`${this.pct}%`)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.barColor)
                }
                .width('100%')
                .height(6)

                Row() {
                  Text(`已花 ${fmtMoney(this.spent)}`)
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                  Blank()
                  Text(`剩余 ${fmtMoney(Math.max(this.budgetAmount - this.spent, 0))}`)
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
                .width('100%')
                .margin({ top: 10 })
              }
              .width('100%')
              .margin({ top: 20 })
            }
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 分类管理 =====
          Column() {
            Row() {
              Text('分类管理')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('+ 新增')
                .fontSize(13)
                .fontColor(this.theme.accent)
                .onClick(() => router.pushUrl({ url: 'pages/Settings' }))
            }
            .width('100%')
            .margin({ bottom: 8 })

            Text('支出分类')
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: 8, bottom: 4 })

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

                Text('✕')
                  .fontSize(16)
                  .fontColor(this.theme.textMuted)
                  .width(32)
                  .height(32)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.deleteCat(cat.id, cat.isDefault))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (cat: Category) => cat.id)

            Text('收入分类')
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .fontWeight(FontWeight.Medium)
              .width('100%')
              .margin({ top: 12, bottom: 4 })

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

                Text('✕')
                  .fontSize(16)
                  .fontColor(this.theme.textMuted)
                  .width(32)
                  .height(32)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.deleteCat(cat.id, cat.isDefault))
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
            }, (cat: Category) => cat.id)
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgPrimary)
  }
}
