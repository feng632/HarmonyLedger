/**
 * 主页 — 仪表盘（收支概览 + 分类环形图 + 最近交易）
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, CategoryStat } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, fmtMoney, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
import { router } from '@kit.ArkUI';

const store = DataStore.getInstance();

interface MonthTxn {
  txns: Transaction[];
  income: number;
  expense: number;
  balance: number;
  catStats: CategoryStat[];
}

interface DonutPart {
  color: string;
  startAngle: number;
  endAngle: number;
}

interface TrendMonth {
  label: string;
  income: number;
  expense: number;
}

@Entry
@Component
struct Index {
  @State themeName: string = 'dark';
  @State theme: ThemeColors = DARK_THEME;

  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State monthData: MonthTxn = {
    txns: [],
    income: 0,
    expense: 0,
    balance: 0,
    catStats: []
  };
  @State cats: Category[] = [];
  @State recentTxns: Transaction[] = [];

  // 环形图数据
  @State donutParts: DonutPart[] = [];
  // 图表刷新版本号（数据更新时自增，强制重建图表）
  @State chartVersion: number = 0;
  // 月度趋势数据（最近 6 个月）
  @State trendData: TrendMonth[] = [];

  // 玻璃模式状态
  @State glassEnabled: boolean = false;
  @State glassBlur: number = 30;
  @State wallpaperPath: string = '';

  aboutToAppear(): void {
    this.loadData();
  }

  // 每次页面显示时刷新（从记一笔返回后数据立即更新）
  onPageShow(): void {
    this.loadData();
  }

  async loadData(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[Index] store init failed: ${JSON.stringify(e)}`);
    }
    // 读取已保存主题
    const savedTheme = await store.getTheme();
    this.themeName = savedTheme;
    // 读取玻璃状态
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(savedTheme) : getTheme(savedTheme);
    this.cats = await store.getCategories();
    await this.loadMonth();
    await this.loadTrend();
    const all = await store.getTransactions();
    this.recentTxns = all.slice(0, 6);
    // 刷新桌面小组件数据
    await store.writeMonthlySummary();
  }

  // 加载最近 6 个月收支趋势
  async loadTrend(): Promise<void> {
    const trend: TrendMonth[] = [];
    for (let i = 5; i >= 0; i--) {
      let m = this.month - i;
      let y = this.year;
      if (m <= 0) { m += 12; y -= 1; }
      const txns = await store.getTransactionsByMonth(y, m);
      let inc = 0;
      let exp = 0;
      for (const t of txns) {
        if (t.type === TxType.Income) inc += t.amount;
        else exp += t.amount;
      }
      trend.push({ label: `${m}月`, income: inc, expense: exp });
    }
    this.trendData = trend;
  }

  // 趋势柱高（按最大值归一化到 55px，两柱总高 ≤ 113px < 容器 120px）
  trendBarHeight(v: number, isIncome: boolean): number {
    let max = 0;
    for (const m of this.trendData) {
      if (m.income > max) max = m.income;
      if (m.expense > max) max = m.expense;
    }
    if (max <= 0) return 2;
    const h = Math.round(v / max * 55);
    return h < 2 ? 2 : h;
  }

  async loadMonth(): Promise<void> {
    const txns = await store.getTransactionsByMonth(this.year, this.month);
    let income = 0;
    let expense = 0;
    const catSum = new Map<string, number>();
    for (const t of txns) {
      if (t.type === TxType.Income) {
        income += t.amount;
      } else {
        expense += t.amount;
        const cur = catSum.get(t.categoryId);
        catSum.set(t.categoryId, (cur ? cur : 0) + t.amount);
      }
    }

    const catStats: CategoryStat[] = [];
    catSum.forEach((amount, catId) => {
      const cat = this.cats.find(c => c.id === catId);
      catStats.push({
        categoryId: catId,
        name: cat ? cat.name : '未分类',
        icon: cat ? cat.icon : '📌',
        color: cat ? cat.color : '#999999',
        amount: amount
      });
    });
    catStats.sort((a, b) => b.amount - a.amount);

    this.monthData = {
      txns: txns,
      income: income,
      expense: expense,
      balance: income - expense,
      catStats: catStats
    };

    this.updateDonut();
  }

  updateDonut(): void {
    const parts: DonutPart[] = [];
    const total = this.monthData.expense;
    if (total <= 0 || this.monthData.catStats.length === 0) {
      this.donutParts = [];
      this.chartVersion++;
      return;
    }
    let cumulative = 0;
    for (const s of this.monthData.catStats) {
      const frac = s.amount / total;
      parts.push({
        color: s.color,
        startAngle: cumulative * 360,
        endAngle: (cumulative + frac) * 360
      });
      cumulative += frac;
    }
    // 先清空再填充 — 强制重建图表（动态编译模式下直接替换不生效）
    this.donutParts = [];
    this.chartVersion++;
    setTimeout(() => {
      this.donutParts = parts;
      this.chartVersion++;
    }, 30);
  }

  changeMonth(delta: number): void {
    let m = this.month + delta;
    let y = this.year;
    if (m > 12) { m = 1; y += 1; }
    if (m < 1) { m = 12; y -= 1; }
    this.year = y;
    this.month = m;
    this.loadMonth();
  }

  goAdd(): void {
    router.pushUrl({ url: 'pages/AddRecord' });
  }

  goRecords(): void {
    router.pushUrl({ url: 'pages/Records' });
  }

  // 分类统计钻取
  goCategoryDetail(categoryId: string): void {
    router.pushUrl({
      url: 'pages/CategoryDetail',
      params: {
        'categoryId': categoryId,
        'year': this.year.toString(),
        'month': this.month.toString()
      }
    });
  }

  // 记账日历
  goCalendar(): void {
    router.pushUrl({ url: 'pages/CalendarPage' });
  }

  catNameOf(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return cat ? cat.name : '未分类';
  }

  catIconOf(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return cat ? cat.icon : '📌';
  }

  catColorBgOf(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return (cat ? cat.color : '#999999') + '22';
  }

  build() {
    Stack() {
      // 玻璃壁纸背景（无壁纸时显示纯色）
      GlassBackground({ wallpaperPath: this.wallpaperPath, blurRadius: this.glassBlur })
        .width('100%')
        .height('100%')

      Column() {
      // ===== 顶部导航 =====
      Row() {
        Text('记账')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)

        Button() {
          Text(this.themeName === 'dark' ? '☀️' : '🌙')
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .backgroundColor(this.theme.bgElevated)
        .borderRadius(18)
        .onClick(() => {
          const next = this.themeName === 'dark' ? 'light' : 'dark';
          this.themeName = next;
          this.theme = getTheme(next);
          store.saveTheme(next);
        })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 8 })

      // ===== 可滚动内容 =====
      Scroll() {
        Column() {
          // 月份选择器
          Row() {
            Text('‹')
              .fontSize(26)
              .fontColor(this.theme.textSecondary)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => this.changeMonth(-1))

            Text(`${this.year}年 ${this.month}月`)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .width(130)
              .textAlign(TextAlign.Center)

            Text('›')
              .fontSize(26)
              .fontColor(this.theme.textSecondary)
              .width(40)
              .height(40)
              .textAlign(TextAlign.Center)
              .onClick(() => this.changeMonth(1))
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 4, bottom: 16 })

          // ===== 余额卡片 =====
          Column() {
            Text('本月余额')
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .letterSpacing(1.5)
              .margin({ top: 20 })

            Text(fmtMoney(this.monthData.balance))
              .fontSize(42)
              .fontWeight(FontWeight.Lighter)
              .fontColor(this.monthData.balance < 0 ? this.theme.expense : this.theme.textPrimary)
              .fontFeature('tnum')
              .margin({ top: 10 })

            Row() {
              Column() {
                Text('↑')
                  .fontSize(12)
                  .fontColor(this.theme.income)
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.theme.incomeBg)
                  .borderRadius(14)
                Text('收入')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .margin({ top: 6 })
                Text(fmtMoney(this.monthData.income))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.income)
                  .fontFeature('tnum')
                  .margin({ top: 2 })
              }
              .layoutWeight(1)

              Divider()
                .vertical(true)
                .height(56)
                .color(this.theme.border)

              Column() {
                Text('↓')
                  .fontSize(12)
                  .fontColor(this.theme.expense)
                  .width(28)
                  .height(28)
                  .textAlign(TextAlign.Center)
                  .backgroundColor(this.theme.expenseBg)
                  .borderRadius(14)
                Text('支出')
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .margin({ top: 6 })
                Text(fmtMoney(this.monthData.expense))
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.expense)
                  .fontFeature('tnum')
                  .margin({ top: 2 })
              }
              .layoutWeight(1)
            }
            .width('100%')
            .margin({ top: 20, bottom: 24 })
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(24)
          .border({ width: 1, color: this.theme.border })
          .shadow({ radius: 16, color: this.theme.shadow, offsetY: 4 })
          .margin({ bottom: 14 })

          // ===== 支出分类环形图 =====
          Column() {
            Text('支出分类')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
              .width('100%')
              .margin({ bottom: 16 })

            if (this.donutParts.length > 0 && this.monthData.expense > 0) {
              // key 使用版本号，数据变化时强制重建图表
              DonutChart({ theme: this.theme, parts: this.donutParts, total: this.monthData.expense })
                .key(`${this.chartVersion}`)
            } else {
              Column() {
                Text('暂无支出数据')
                  .fontSize(14)
                  .fontColor(this.theme.textMuted)
              }
              .width('100%')
              .padding(30)
              .justifyContent(FlexAlign.Center)
            }

            if (this.monthData.catStats.length > 0) {
              Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Center }) {
                ForEach(this.monthData.catStats, (s: CategoryStat) => {
                  Row() {
                    Row()
                      .width(8)
                      .height(8)
                      .borderRadius(2)
                      .backgroundColor(s.color)
                    Text(` ${s.name}`)
                      .fontSize(12)
                      .fontColor(this.theme.textSecondary)
                    Text(` ${s.amount > 0 ? Math.round(s.amount / this.monthData.expense * 100) : 0}%`)
                      .fontSize(12)
                      .fontColor(this.theme.textPrimary)
                      .fontWeight(FontWeight.Medium)
                  }
                  .margin({ right: 14, bottom: 8 })
                  .onClick(() => this.goCategoryDetail(s.categoryId))
                }, (s: CategoryStat) => s.categoryId)
              }
              .width('100%')
              .margin({ top: 16 })
            }
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 月度趋势图 =====
          Column() {
            Row() {
              Text('月度趋势')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('日历 ›')
                .fontSize(13)
                .fontColor(this.theme.accent)
                .onClick(() => this.goCalendar())
            }
            .width('100%')
            .margin({ bottom: 16 })

            if (this.trendData.length === 0) {
              Column() {
                Text('暂无数据')
                  .fontSize(14)
                  .fontColor(this.theme.textMuted)
              }
              .width('100%')
              .padding(20)
              .justifyContent(FlexAlign.Center)
            } else {
              // 图例
              Row() {
                Row() {
                  Row()
                    .width(10)
                    .height(10)
                    .borderRadius(2)
                    .backgroundColor(this.theme.income)
                  Text(' 收入')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                }
                .margin({ right: 16 })

                Row() {
                  Row()
                    .width(10)
                    .height(10)
                    .borderRadius(2)
                    .backgroundColor(this.theme.expense)
                  Text(' 支出')
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                }
              }
              .width('100%')
              .margin({ bottom: 12 })

              // 柱状图：每月两组柱子（收入/支出）
              Row() {
                ForEach(this.trendData, (m: TrendMonth) => {
                  Column() {
                    // 柱子区（固定高度，柱高按比例）
                    Column() {
                      Row()
                        .width(10)
                        .height(this.trendBarHeight(m.income, true))
                        .borderRadius(3)
                        .backgroundColor(this.theme.income)
                      Blank().height(3)
                      Row()
                        .width(10)
                        .height(this.trendBarHeight(m.expense, false))
                        .borderRadius(3)
                        .backgroundColor(this.theme.expense)
                    }
                    .height(120)
                    .justifyContent(FlexAlign.End)
                    .alignItems(HorizontalAlign.Center)

                    Text(m.label)
                      .fontSize(10)
                      .fontColor(this.theme.textSecondary)
                      .margin({ top: 6 })
                  }
                  .layoutWeight(1)
                }, (m: TrendMonth) => m.label)
              }
              .width('100%')
              .alignItems(VerticalAlign.Bottom)
            }
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 14 })

          // ===== 最近交易 =====
          Column() {
            Row() {
              Text('最近交易')
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
                .layoutWeight(1)
              Text('查看全部')
                .fontSize(13)
                .fontColor(this.theme.accent)
                .onClick(() => this.goRecords())
            }
            .width('100%')
            .margin({ bottom: 8 })

            if (this.recentTxns.length === 0) {
              Column() {
                Text('还没有交易记录，点击下方 + 记一笔吧')
                  .fontSize(13)
                  .fontColor(this.theme.textMuted)
              }
              .width('100%')
              .padding(24)
              .justifyContent(FlexAlign.Center)
            } else {
              ForEach(this.recentTxns, (tx: Transaction) => {
                Row() {
                  Text(this.catIconOf(tx))
                    .fontSize(20)
                    .width(42)
                    .height(42)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.catColorBgOf(tx))
                    .borderRadius(9)

                  Column() {
                    Text(this.catNameOf(tx))
                      .fontSize(15)
                      .fontColor(this.theme.textPrimary)
                      .fontWeight(FontWeight.Medium)
                    if (tx.note.length > 0) {
                      Text(tx.note)
                        .fontSize(12)
                        .fontColor(this.theme.textSecondary)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 2 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 12 })

                  Text((tx.type === TxType.Expense ? '-' : '+') + ' ' + fmtMoney(tx.amount))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(tx.type === TxType.Expense ? this.theme.expense : this.theme.income)
                    .fontFeature('tnum')
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
              }, (tx: Transaction) => tx.id)
            }
          }
          .width('100%')
          .backgroundColor(this.theme.bgCard)
          .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
          .borderRadius(20)
          .border({ width: 1, color: this.theme.border })
          .padding(20)
          .margin({ bottom: 20 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // ===== 底部导航 =====
      Row() {
        Column() {
          Text('▦')
            .fontSize(20)
            .fontColor(this.theme.accent)
          Text('概览')
            .fontSize(10)
            .fontColor(this.theme.accent)
            .fontWeight(FontWeight.Medium)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)

        Column() {
          Text('☰')
            .fontSize(20)
            .fontColor(this.theme.textMuted)
          Text('账单')
            .fontSize(10)
            .fontColor(this.theme.textMuted)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .onClick(() => this.goRecords())

        Column() {
          Text('+')
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .width(52)
            .height(52)
            .textAlign(TextAlign.Center)
            .backgroundColor(this.theme.accent)
            .borderRadius(26)
            .shadow({ radius: 12, color: this.theme.accent + '66', offsetY: 4 })
        }
        .width(72)
        .justifyContent(FlexAlign.Center)
        .margin({ top: -24 })
        .onClick(() => this.goAdd())

        Column() {
          Text('◷')
            .fontSize(20)
            .fontColor(this.theme.textMuted)
          Text('预算')
            .fontSize(10)
            .fontColor(this.theme.textMuted)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .onClick(() => router.pushUrl({ url: 'pages/Budget' }))

        Column() {
          Text('⚙')
            .fontSize(20)
            .fontColor(this.theme.textMuted)
          Text('设置')
            .fontSize(10)
            .fontColor(this.theme.textMuted)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .onClick(() => router.pushUrl({ url: 'pages/Settings' }))
      }
      .width('100%')
      .height(64)
      .padding({ bottom: 8 })
      .backgroundColor(this.glassEnabled ? 'rgba(255,255,255,0.12)' : this.theme.bgPrimary)
      .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
      }
      .width('100%')
      .height('100%')
      .backgroundColor(this.glassEnabled ? 'rgba(0,0,0,0)' : this.theme.bgPrimary)
    }
    .width('100%')
    .height('100%')
  }
}

/**
 * 环形图部件 — 使用圆环 strokeDashArray 分段绘制
 */
@Component
struct DonutChart {
  @Prop theme: ThemeColors = DARK_THEME;
  parts: DonutPart[] = [];
  total: number = 0;

  // 圆环周长：直径 180，stroke 中心半径 90
  private static CIRCUMFERENCE = 2 * Math.PI * 90;

  build() {
    Column() {
      Stack({ alignContent: Alignment.Center }) {
        // 底环
        Circle()
          .width(180)
          .height(180)
          .fillOpacity(0)
          .stroke(this.theme.border)
          .strokeWidth(18)

        // 分段
        ForEach(this.parts, (p: DonutPart) => {
          Circle()
            .width(180)
            .height(180)
            .fillOpacity(0)
            .stroke(p.color)
            .strokeWidth(18)
            .strokeLineCap(LineCapStyle.Round)
            .rotate({
              angle: p.startAngle - 90,
              centerX: '50%',
              centerY: '50%'
            })
            .strokeDashArray([
              (p.endAngle - p.startAngle) / 360 * DonutChart.CIRCUMFERENCE,
              1000
            ])
        }, (p: DonutPart) => `${p.startAngle}-${p.endAngle}-${p.color}`)

        // 中心文字
        Column() {
          Text('总支出')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
          Text(fmtMoney(this.total))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
            .fontFeature('tnum')
            .margin({ top: 4 })
        }
      }
      .width(200)
      .height(200)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }
}