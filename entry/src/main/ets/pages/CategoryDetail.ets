/**
 * 分类统计钻取 — 查看某分类在指定月份的明细记录
 * 路由参数: categoryId, year, month
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, DateUtil, formatCurrency } from '../model/Models';
import { ThemeColors, getTheme, getGlassTheme, DARK_THEME } from '../common/Theme';
import { GlassBackground, loadGlassState } from '../common/GlassComponents';
import { router } from '@kit.ArkUI';

const store = DataStore.getInstance();

@Entry
@Component
struct CategoryDetail {
  @State theme: ThemeColors = DARK_THEME;

  @State cats: Category[] = [];
  @State categoryId: string = '';
  @State year: number = new Date().getFullYear();
  @State month: number = new Date().getMonth() + 1;
  @State records: Transaction[] = [];
  @State totalAmount: number = 0;
  @State cat: Category | null = null;

  // 玻璃状态
  @State glassEnabled: boolean = false;
  @State glassBlur: number = 30;
  @State wallpaperPath: string = '';

  aboutToAppear(): void {
    // 读取路由参数
    const params = router.getParams() as Record<string, Object>;
    if (params) {
      this.categoryId = params['categoryId'] as string;
      this.year = parseInt(params['year'] as string);
      this.month = parseInt(params['month'] as string);
    }
    this.load();
  }

  async load(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[CategoryDetail] init failed: ${JSON.stringify(e)}`);
    }
    const savedTheme = await store.getTheme();
    const glass = await loadGlassState(this.getUIContext().getHostContext());
    this.glassEnabled = glass.enabled;
    this.glassBlur = glass.blur;
    this.wallpaperPath = glass.wallpaperPath;
    this.theme = glass.enabled ? getGlassTheme(savedTheme) : getTheme(savedTheme);

    this.cats = await store.getCategories();
    this.cat = this.cats.find(c => c.id === this.categoryId) || null;

    const txns = await store.getTransactionsByMonth(this.year, this.month);
    const filtered = txns.filter(t => t.categoryId === this.categoryId);
    this.records = filtered;

    let total = 0;
    for (const t of filtered) total += t.amount;
    this.totalAmount = total;
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

          Text(this.cat ? this.cat.name : '分类明细')
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
            // 汇总卡
            Column() {
              Text(this.cat ? this.cat.icon : '📌')
                .fontSize(28)
                .width(56)
                .height(56)
                .textAlign(TextAlign.Center)
                .backgroundColor(this.cat ? this.cat.color + '22' : '#99999922')
                .borderRadius(14)
              Text(`${this.year}年${this.month}月`)
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .margin({ top: 8 })
              Text(formatCurrency(this.totalAmount))
                .fontSize(32)
                .fontWeight(FontWeight.Lighter)
                .fontColor(this.theme.textPrimary)
                .fontFeature('tnum')
                .margin({ top: 6 })
              Text(`${this.records.length} 笔记录`)
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
                .margin({ top: 4 })
            }
            .width('100%')
            .padding(24)
            .backgroundColor(this.theme.bgCard)
            .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
            .borderRadius(20)
            .border({ width: 1, color: this.theme.border })
            .margin({ bottom: 14 })

            // 记录列表
            if (this.records.length === 0) {
              Column() {
                Text('本月该分类暂无记录')
                  .fontSize(13)
                  .fontColor(this.theme.textMuted)
              }
              .width('100%')
              .padding(40)
              .justifyContent(FlexAlign.Center)
            } else {
              Column() {
                ForEach(this.records, (tx: Transaction, index: number) => {
                  Row() {
                    Text(this.cat ? this.cat.icon : '📌')
                      .fontSize(20)
                      .width(42)
                      .height(42)
                      .textAlign(TextAlign.Center)
                      .backgroundColor((this.cat ? this.cat.color : '#999999') + '22')
                      .borderRadius(9)

                    Column() {
                      Text(tx.note.length > 0 ? tx.note : this.cat ? this.cat.name : '未分类')
                        .fontSize(15)
                        .fontColor(this.theme.textPrimary)
                        .fontWeight(FontWeight.Medium)
                        .maxLines(1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                      Text(DateUtil.formatDisplay(tx.date))
                        .fontSize(12)
                        .fontColor(this.theme.textSecondary)
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)
                    .margin({ left: 12 })

                    Text((tx.type === TxType.Expense ? '-' : '+') + ' ' + formatCurrency(tx.amount))
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(tx.type === TxType.Expense ? this.theme.expense : this.theme.income)
                      .fontFeature('tnum')
                  }
                  .width('100%')
                  .padding({ top: 12, bottom: 12 })
                  // 最后一条记录不显示底线
                  .border({
                    width: { bottom: index === this.records.length - 1 ? 0 : 1 },
                    color: this.glassEnabled ? 'rgba(255,255,255,0.08)' : this.theme.borderLight
                  })
                }, (tx: Transaction) => tx.id)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .backgroundColor(this.theme.bgCard)
              .backdropBlur(this.glassEnabled ? this.glassBlur : 0)
              .borderRadius(20)
              .border({ width: 1, color: this.theme.border })
              .padding({ top: 4, bottom: 4 })
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
