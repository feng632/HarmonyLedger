/**
 * 记账日历热力图 — 每月日历，每天颜色深浅表示花销
 * 点击某天查看当天记录
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, DateUtil, formatCurrency } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
import { router } from '@kit.ArkUI';

const store = DataStore.getInstance();

interface DayCell {
  day: number;        // 0 = 空位
  net: number;        // 当天净收入（收入-支出）
  hasData: boolean;
}

@Entry
@Component
struct CalendarPage {
  @State theme: ThemeColors = DARK_THEME;

  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State cells: DayCell[] = [];
  @State dayTxns: Transaction[] = [];
  @State selectedDay: number = 0;
  @State cats: Category[] = [];

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
      console.error(`[Calendar] init failed: ${JSON.stringify(e)}`);
    }
    const savedTheme = await store.getTheme();
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(savedTheme) : getTheme(savedTheme);
    this.cats = await store.getCategories();
    await this.loadMonth();
  }

  async loadMonth(): Promise<void> {
    // 当月每天净收入（收入-支出）
    const txns = await store.getTransactionsByMonth(this.year, this.month);
    const dayNet = new Map<number, number>();
    for (const t of txns) {
      const day = parseInt(t.date.split('-')[2]);
      const cur = dayNet.get(day);
      const val = t.type === TxType.Income ? t.amount : -t.amount;
      dayNet.set(day, (cur ? cur : 0) + val);
    }

    // 构建日历格子（含月初空位）
    const firstDay = new Date(this.year, this.month - 1, 1);
    const startWeekday = firstDay.getDay(); // 0=周日
    const daysInMonth = new Date(this.year, this.month, 0).getDate();

    const cells: DayCell[] = [];
    for (let i = 0; i < startWeekday; i++) {
      cells.push({ day: 0, net: 0, hasData: false });
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const net = dayNet.get(d) || 0;
      cells.push({ day: d, net: net, hasData: net !== 0 });
    }

    this.cells = cells;

    // 默认选中今天（若在本月）
    const today = new Date();
    if (today.getFullYear() === this.year && today.getMonth() + 1 === this.month) {
      this.selectedDay = today.getDate();
    } else {
      this.selectedDay = 0;
    }
    await this.loadDay();
  }

  // 加载选中天的记录
  async loadDay(): Promise<void> {
    if (this.selectedDay <= 0) {
      this.dayTxns = [];
      return;
    }
    const dateStr = `${this.year}-${DateUtil.pad2(this.month)}-${DateUtil.pad2(this.selectedDay)}`;
    const txns = await store.getTransactionsByMonth(this.year, this.month);
    this.dayTxns = txns.filter(t => t.date === dateStr);
  }

  // 格子颜色：净收入为正用绿色（深浅分级），为负用红色（深浅分级）
  cellColor(net: number): string {
    if (net === 0) return 'rgba(255,255,255,0.06)';
    // 计算最大绝对值做归一化
    let max = 0;
    for (const c of this.cells) {
      const a = Math.abs(c.net);
      if (a > max) max = a;
    }
    if (max <= 0) return 'rgba(232,141,125,0.25)';
    const ratio = Math.abs(net) / max;
    let alpha = 0.20;
    if (ratio >= 0.25) alpha = 0.35;
    if (ratio >= 0.5) alpha = 0.55;
    if (ratio >= 0.75) alpha = 0.75;
    if (ratio >= 0.95) alpha = 0.9;
    // 正 → 绿色，负 → 红色
    if (net > 0) {
      return `rgba(125,206,160,${alpha})`;
    } else {
      return `rgba(232,141,125,${alpha})`;
    }
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

  changeMonth(delta: number): void {
    let m = this.month + delta;
    let y = this.year;
    if (m > 12) { m = 1; y += 1; }
    if (m < 1) { m = 12; y -= 1; }
    this.year = y;
    this.month = m;
    this.selectedDay = 0;
    this.loadMonth();
  }

  build() {
    Stack() {
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

          Text('记账日历')
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
            // ===== 月份切换 + 日历卡 =====
            Column() {
              Row() {
                Text('‹')
                  .fontSize(24)
                  .fontColor(this.theme.textSecondary)
                  .width(36)
                  .height(36)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.changeMonth(-1))

                Text(`${this.year}年 ${this.month}月`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.textPrimary)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Center)

                Text('›')
                  .fontSize(24)
                  .fontColor(this.theme.textSecondary)
                  .width(36)
                  .height(36)
                  .textAlign(TextAlign.Center)
                  .onClick(() => this.changeMonth(1))
              }
              .width('100%')
              .margin({ bottom: 10 })

              // 星期标题
              Row() {
                ForEach(['日', '一', '二', '三', '四', '五', '六'], (w: string) => {
                  Text(w)
                    .fontSize(11)
                    .fontColor(this.theme.textSecondary)
                    .layoutWeight(1)
                    .textAlign(TextAlign.Center)
                }, (w: string) => w)
              }
              .width('100%')
              .margin({ bottom: 8 })

              // 日历格子（6 行 7 列）
              Grid() {
                ForEach(this.cells, (cell: DayCell) => {
                  GridItem() {
                    if (cell.day === 0) {
                      Blank()
                        .width('100%')
                        .height(44)
                    } else {
                      Stack() {
                        // 圆点标记（绝对定位，不占布局，数字保持居中）
                        if (cell.hasData) {
                          Text('·')
                            .fontSize(8)
                            .fontColor(cell.net > 0 ? this.theme.income : this.theme.expense)
                            .align(Alignment.Bottom)
                            .margin({ bottom: 3 })
                        }
                        // 日期数字（严格居中）
                        Text(cell.day.toString())
                          .fontSize(13)
                          .fontColor(this.selectedDay === cell.day ? Color.White : this.theme.textPrimary)
                          .fontWeight(this.selectedDay === cell.day ? FontWeight.Medium : FontWeight.Regular)
                          .textAlign(TextAlign.Center)
                      }
                      .width('100%')
                      .height(44)
                      .alignContent(Alignment.Center)
                      .backgroundColor(this.cellColor(cell.net))
                      .borderRadius(8)
                      .border({
                        width: this.selectedDay === cell.day ? 2 : 0,
                        color: this.theme.accent
                      })
                      .onClick(() => {
                        this.selectedDay = cell.day;
                        this.loadDay();
                      })
                    }
                  }
                }, (cell: DayCell) => cell.day.toString())
              }
              .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
              .rowsGap(4)
              .columnsGap(4)
              .width('100%')

              // 图例
              Row() {
                Text('亏')
                  .fontSize(10)
                  .fontColor(this.theme.textSecondary)
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(232,141,125,0.20)')
                  .margin({ left: 6 })
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(232,141,125,0.55)')
                  .margin({ left: 6 })
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(232,141,125,0.9)')
                  .margin({ left: 6 })
                Text('亏')
                  .fontSize(10)
                  .fontColor(this.theme.textSecondary)
                  .margin({ left: 6, right: 16 })
                Text('盈')
                  .fontSize(10)
                  .fontColor(this.theme.textSecondary)
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(125,206,160,0.20)')
                  .margin({ left: 6 })
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(125,206,160,0.55)')
                  .margin({ left: 6 })
                Row()
                  .width(10)
                  .height(10)
                  .borderRadius(2)
                  .backgroundColor('rgba(125,206,160,0.9)')
                  .margin({ left: 6 })
              }
              .width('100%')
              .justifyContent(FlexAlign.Center)
              .margin({ top: 12 })
            }
            .width('100%')
            .padding(16)
            .backgroundColor(this.theme.bgCard)
            .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
            .borderRadius(20)
            .border({ width: 1, color: this.theme.border })
            .margin({ bottom: 14 })

            // ===== 选中日期的记录 =====
            if (this.selectedDay > 0) {
              Column() {
                Row() {
                  Text(`${this.month}月${this.selectedDay}日`)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                    .layoutWeight(1)
                  Text(`${this.dayTxns.length} 笔`)
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
                .width('100%')
                .margin({ bottom: 8 })

                if (this.dayTxns.length === 0) {
                  Text('当天无记录')
                    .fontSize(12)
                    .fontColor(this.theme.textMuted)
                    .width('100%')
                    .padding(16)
                } else {
                  ForEach(this.dayTxns, (tx: Transaction) => {
                    Row() {
                      Text(this.catIconOf(tx))
                        .fontSize(18)
                        .width(38)
                        .height(38)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(this.catColorBgOf(tx))
                        .borderRadius(8)

                      Column() {
                        Text(this.catNameOf(tx))
                          .fontSize(14)
                          .fontColor(this.theme.textPrimary)
                          .fontWeight(FontWeight.Medium)
                        if (tx.note.length > 0) {
                          Text(tx.note)
                            .fontSize(11)
                            .fontColor(this.theme.textSecondary)
                            .maxLines(1)
                            .textOverflow({ overflow: TextOverflow.Ellipsis })
                        }
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      .margin({ left: 10 })

                      Text((tx.type === TxType.Expense ? '-' : '+') + ' ' + formatCurrency(tx.amount))
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(tx.type === TxType.Expense ? this.theme.expense : this.theme.income)
                        .fontFeature('tnum')
                    }
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })
                  }, (tx: Transaction) => tx.id)
                }
              }
              .width('100%')
              .padding(16)
              .backgroundColor(this.theme.bgCard)
              .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
              .borderRadius(20)
              .border({ width: 1, color: this.theme.border })
            }
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
