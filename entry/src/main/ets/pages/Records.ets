/**
 * 账单 — 全部交易记录（按日期分组，支持筛选/搜索/长按删除）
 */
import { DataStore } from '../model/DataStore';
import { Category, Transaction, TxType, DateUtil, formatCurrency } from '../model/Models';
import { ThemeColors, getTheme, DARK_THEME } from '../common/Theme';
import { router } from '@kit.ArkUI';
import { promptAction } from '@kit.ArkUI';

const store = DataStore.getInstance();

interface DayGroup {
  date: string;
  label: string;
  items: Transaction[];
}

@Entry
@Component
struct Records {
  @State theme: ThemeColors = DARK_THEME;

  @State cats: Category[] = [];
  @State groups: DayGroup[] = [];
  @State filter: string = 'all'; // all | expense | income
  @State search: string = '';
  // 列表刷新版本号（数据变化时自增，强制重建 List）
  @State listVersion: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  async load(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext();
      if (ctx) { await store.ensureInit(ctx); }
    } catch (e) {
      console.error(`[Records] store init failed: ${JSON.stringify(e)}`);
    }
    this.theme = getTheme(await store.getTheme());
    this.cats = await store.getCategories();
    let txns = await store.getTransactions();

    if (this.filter === 'expense') {
      txns = txns.filter(t => t.type === TxType.Expense);
    } else if (this.filter === 'income') {
      txns = txns.filter(t => t.type === TxType.Income);
    }

    if (this.search.length > 0) {
      const kw = this.search.toLowerCase();
      txns = txns.filter(t => {
        const cat = this.cats.find(c => c.id === t.categoryId);
        const catName = cat ? cat.name.toLowerCase() : '';
        return catName.includes(kw) || t.note.toLowerCase().includes(kw);
      });
    }

    // 按日期分组
    const map = new Map<string, Transaction[]>();
    for (const t of txns) {
      const list = map.get(t.date);
      if (list) {
        list.push(t);
      } else {
        map.set(t.date, [t]);
      }
    }

    const dates = Array.from(map.keys()).sort((a, b) => b.localeCompare(a));
    const groups: DayGroup[] = [];
    for (const d of dates) {
      groups.push({
        date: d,
        label: DateUtil.formatDisplay(d),
        items: map.get(d) as Transaction[]
      });
    }
    this.groups = groups;
    this.listVersion++;
  }

  setFilter(f: string): void {
    this.filter = f;
    this.load();
  }

  catName(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return cat ? cat.name : '未分类';
  }

  catIcon(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return cat ? cat.icon : '📌';
  }

  catColorBg(tx: Transaction): string {
    const cat = this.cats.find(c => c.id === tx.categoryId);
    return (cat ? cat.color : '#999999') + '22';
  }

  deleteTx(id: string): void {
    promptAction.showDialog({
      title: '删除记录',
      message: '确定删除这条记录吗？',
      buttons: [
        { text: '取消', color: this.theme.textSecondary },
        { text: '删除', color: this.theme.danger }
      ]
    }).then((res) => {
      if (res.index === 1) {
        store.deleteTransaction(id).then(() => {
          this.load();
          promptAction.showToast({ message: '已删除' });
        });
      }
    }).catch(() => {});
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

        Text('账单')
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Blank().width(40)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 6 })

      // ===== 搜索 =====
      Row() {
        Text('🔍')
          .fontSize(14)
        TextInput({ placeholder: '搜索交易...', text: this.search })
          .fontSize(14)
          .placeholderColor(this.theme.textMuted)
          .backgroundColor(Color.Transparent)
          .layoutWeight(1)
          .margin({ left: 8 })
          .onChange((v: string) => {
            this.search = v;
            this.load();
          })
      }
      .width('100%')
      .backgroundColor(this.theme.bgCard)
      .borderRadius(14)
      .border({ width: 1, color: this.theme.border })
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .margin({ left: 16, right: 16, bottom: 10 })

      // ===== 筛选 chips =====
      Row() {
        Text('全部')
          .fontSize(13)
          .fontWeight(this.filter === 'all' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.filter === 'all' ? Color.White : this.theme.textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.filter === 'all' ? this.theme.accent : this.theme.bgCard)
          .borderRadius(20)
          .border({ width: 1, color: this.filter === 'all' ? this.theme.accent : this.theme.border })
          .onClick(() => this.setFilter('all'))

        Text('支出')
          .fontSize(13)
          .fontWeight(this.filter === 'expense' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.filter === 'expense' ? Color.White : this.theme.textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.filter === 'expense' ? this.theme.accent : this.theme.bgCard)
          .borderRadius(20)
          .border({ width: 1, color: this.filter === 'expense' ? this.theme.accent : this.theme.border })
          .margin({ left: 8 })
          .onClick(() => this.setFilter('expense'))

        Text('收入')
          .fontSize(13)
          .fontWeight(this.filter === 'income' ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.filter === 'income' ? Color.White : this.theme.textSecondary)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.filter === 'income' ? this.theme.accent : this.theme.bgCard)
          .borderRadius(20)
          .border({ width: 1, color: this.filter === 'income' ? this.theme.accent : this.theme.border })
          .margin({ left: 8 })
          .onClick(() => this.setFilter('income'))
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 12 })

      // ===== 列表 =====
      if (this.groups.length === 0) {
        Column() {
          Text('· · ·')
            .fontSize(28)
            .fontColor(this.theme.textMuted)
            .margin({ bottom: 8 })
          Text('暂无交易记录')
            .fontSize(14)
            .fontColor(this.theme.textMuted)
        }
        .width('100%')
        .padding(60)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0 }) {
          ForEach(this.groups, (group: DayGroup) => {
            ListItem() {
              Column() {
                Text(group.label)
                  .fontSize(12)
                  .fontColor(this.theme.textSecondary)
                  .fontWeight(FontWeight.Medium)
                  .width('100%')
                  .padding({ top: 16, bottom: 8 })
              }
            }

            ForEach(group.items, (tx: Transaction) => {
              ListItem() {
                Row() {
                  Text(this.catIcon(tx))
                    .fontSize(20)
                    .width(42)
                    .height(42)
                    .textAlign(TextAlign.Center)
                    .backgroundColor(this.catColorBg(tx))
                    .borderRadius(9)

                  Column() {
                    Text(this.catName(tx))
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

                  Text((tx.type === TxType.Expense ? '-' : '+') + ' ' + formatCurrency(tx.amount))
                    .fontSize(15)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(tx.type === TxType.Expense ? this.theme.expense : this.theme.income)
                    .fontFeature('tnum')
                }
                .width('100%')
                .padding({ top: 12, bottom: 12 })
                .gesture(
                  LongPressGesture()
                    .onAction(() => this.deleteTx(tx.id))
                )
              }
            }, (tx: Transaction) => tx.id)
          }, (group: DayGroup) => group.date)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .key(`${this.listVersion}`)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgPrimary)
  }
}
