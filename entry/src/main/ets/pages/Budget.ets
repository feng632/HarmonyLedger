/**
 * 预算 — 月度预算 + 分类管理
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, Budget } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, fmtMoney, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
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

  // 分类预算状态
  @State catBudgetMap: Map<string, number> = new Map();   // 分类ID -> 预算
  @State catSpentMap: Map<string, number> = new Map();    // 分类ID -> 已花
  @State editingCatId: string = '';                       // 正在编辑预算的分类
  @State editingCatStr: string = '';                      // 编辑中的预算文本

  // 玻璃模式状态
  @State glassEnabled: boolean = false;
  @State glassBlur: number = 30;
  @State wallpaperPath: string = '';

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
    const savedTheme = await store.getTheme();
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(savedTheme) : getTheme(savedTheme);
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

    // 加载分类预算 + 各分类已花
    await this.loadCategoryBudgets(txns);
  }

  // 加载所有支出分类的预算和已花
  async loadCategoryBudgets(txns: Transaction[]): Promise<void> {
    const expenseCats = this.cats.filter(c => c.type === TxType.Expense);
    const budgetMap = new Map<string, number>();
    const spentMap = new Map<string, number>();

    // 各分类已花
    for (const t of txns) {
      if (t.type !== TxType.Expense) continue;
      const cur = spentMap.get(t.categoryId);
      spentMap.set(t.categoryId, (cur ? cur : 0) + t.amount);
    }

    // 各分类预算
    for (const cat of expenseCats) {
      const b = await store.getCategoryBudget(cat.id, this.year, this.month);
      budgetMap.set(cat.id, b);
    }

    this.catBudgetMap = budgetMap;
    this.catSpentMap = spentMap;
  }

  // 开始编辑分类预算
  startEditCatBudget(catId: string, current: number): void {
    this.editingCatId = catId;
    this.editingCatStr = current > 0 ? current.toString() : '';
  }

  // 保存分类预算
  async saveCatBudget(): Promise<void> {
    if (this.editingCatId === '') return;
    const amt = parseFloat(this.editingCatStr);
    if (isNaN(amt) || amt < 0) {
      promptAction.showToast({ message: '请输入有效预算金额' });
      return;
    }
    await store.saveCategoryBudget(this.editingCatId, this.year, this.month, amt);
    this.editingCatId = '';
    this.editingCatStr = '';
    promptAction.showToast({ message: amt > 0 ? '分类预算已保存' : '分类预算已清除' });
    // 刷新
    const txns = await store.getTransactionsByMonth(this.year, this.month);
    await this.loadCategoryBudgets(txns);
  }

  // 分类预算使用率
  catBudgetPct(catId: string): number {
    const budget = this.catBudgetMap.get(catId) || 0;
    const spent = this.catSpentMap.get(catId) || 0;
    if (budget <= 0) return 0;
    return Math.min(spent / budget * 100, 100);
  }

  // 分类预算状态文字
  catBudgetLine(catId: string): string {
    const budget = this.catBudgetMap.get(catId) || 0;
    const spent = this.catSpentMap.get(catId) || 0;
    if (budget <= 0) return '未设置预算';
    const pct = Math.round(spent / budget * 100);
    return `已花 ${pct}%`;
  }

  // 分类预算进度条颜色
  catBudgetColor(pct: number): string {
    if (pct >= 90) return this.theme.danger;
    if (pct >= 70) return this.theme.warning;
    return this.theme.accent;
  }

  // 预算使用率（普通方法，避免 getter this 绑定问题）
  calcPct(): number {
    if (this.budgetAmount <= 0) return 0;
    return Math.min(this.spent / this.budgetAmount * 100, 100);
  }

  calcBarColor(): string {
    const p = this.calcPct();
    if (p >= 90) return this.theme.danger;
    if (p >= 70) return this.theme.warning;
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
                    .width(`${this.calcPct()}%`)
                    .height(6)
                    .borderRadius(3)
                    .backgroundColor(this.calcBarColor())
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
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 分类预算 =====
          Column() {
            Row() {
              Text('分类预算')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('为每个支出分类单独设预算')
                .fontSize(11)
                .fontColor(this.theme.textMuted)
            }
            .width('100%')
            .margin({ bottom: 8 })

            // 各支出分类预算行
            ForEach(this.cats.filter(c => c.type === TxType.Expense), (cat: Category) => {
              Column() {
                // 分类行：图标 + 名称 + 预算/已花
                Row() {
                  Text(cat.icon)
                    .fontSize(16)
                    .width(34)
                    .height(34)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(cat.color + '22')
                    .borderRadius(8)

                  Column() {
                    Text(cat.name)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme.textPrimary)
                    Text(this.catBudgetLine(cat.id))
                      .fontSize(11)
                      .fontColor(this.theme.textSecondary)
                      .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 10 })

                  // 编辑按钮 / 保存按钮
                  if (this.editingCatId === cat.id) {
                    Row() {
                      TextInput({ placeholder: '预算', text: this.editingCatStr })
                        .fontSize(13)
                        .type(InputType.NUMBER_DECIMAL)
                        .placeholderColor(this.theme.textMuted)
                        .backgroundColor(Color.Transparent)
                        .width(70)
                        .height(32)
                        .onChange((v: string) => this.editingCatStr = v)
                      Text('✓')
                        .fontSize(16)
                        .fontColor(this.theme.income)
                        .width(32)
                        .height(32)
                        .textAlign(TextAlign.Center)
                        .onClick(() => this.saveCatBudget())
                      Text('✕')
                        .fontSize(14)
                        .fontColor(this.theme.textMuted)
                        .width(28)
                        .height(32)
                        .textAlign(TextAlign.Center)
                        .onClick(() => {
                          this.editingCatId = '';
                          this.editingCatStr = '';
                        })
                    }
                  } else {
                    Row() {
                      if ((this.catBudgetMap.get(cat.id) || 0) > 0) {
                        Text(`${fmtMoney(this.catSpentMap.get(cat.id) || 0)} / ${fmtMoney(this.catBudgetMap.get(cat.id) || 0)}`)
                          .fontSize(11)
                          .fontColor(this.theme.textSecondary)
                          .margin({ right: 6 })
                      }
                      Text('设置')
                        .fontSize(12)
                        .fontColor(this.theme.accent)
                        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                        .backgroundColor(this.theme.accentMuted)
                        .borderRadius(6)
                        .onClick(() => this.startEditCatBudget(cat.id, this.catBudgetMap.get(cat.id) || 0))
                    }
                  }
                }
                .width('100%')
                .padding({ top: 8, bottom: 8 })

                // 进度条（有预算时显示）
                if ((this.catBudgetMap.get(cat.id) || 0) > 0) {
                  Stack({ alignContent: Alignment.Start }) {
                    Row()
                      .width('100%')
                      .height(4)
                      .borderRadius(2)
                      .backgroundColor(this.theme.bgElevated)
                    Row()
                      .width(`${this.catBudgetPct(cat.id)}%`)
                      .height(4)
                      .borderRadius(2)
                      .backgroundColor(this.catBudgetColor(this.catBudgetPct(cat.id)))
                  }
                  .width('100%')
                  .height(4)
                  .margin({ bottom: 4 })
                }
              }
              .width('100%')
              .border({ width: { bottom: 1 }, color: this.theme.borderLight })
            }, (cat: Category) => cat.id)
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
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
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
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
      .backgroundColor(this.glassEnabled ? 'rgba(0,0,0,0)' : this.theme.bgPrimary)
    }
    .width('100%')
    .height('100%')
  }
}
