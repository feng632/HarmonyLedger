/**
 * 共享组件 — 分类图标 / 列表空态 / 交易行 / 日期标题
 * 主题通过 @StorageLink('themeName') + getter 获取，保证全局响应式
 */
import { ThemeColors, getTheme, fmtMoney } from './Theme';
import { Category } from '../model/Models';

/**
 * 分类图标圆块
 */
@Component
export struct CategoryIcon {
  @Prop icon: string = '📌';
  @Prop color: string = '#999999';
  @Prop size: number = 44;

  build() {
    Text(this.icon)
      .fontSize(this.size * 0.48)
      .width(this.size)
      .height(this.size)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.color + '22')
      .borderRadius(this.size * 0.2)
  }

  @StorageLink('themeName') themeName: string = 'dark';
  get theme(): ThemeColors {
    return getTheme(this.themeName);
  }
}

/**
 * 列表空态
 */
@Component
export struct EmptyState {
  @Prop text: string = '暂无数据';

  build() {
    Column() {
      Text('· · ·')
        .fontSize(28)
        .fontColor(this.theme.textMuted)
        .margin({ bottom: 8 })
      Text(this.text)
        .fontSize(14)
        .fontColor(this.theme.textMuted)
    }
    .width('100%')
    .padding(40)
    .justifyContent(FlexAlign.Center)
  }

  @StorageLink('themeName') themeName: string = 'dark';
  get theme(): ThemeColors {
    return getTheme(this.themeName);
  }
}

/**
 * 交易行组件
 */
@Component
export struct TxRow {
  icon: string = '📌';
  catName: string = '未分类';
  note: string = '';
  amount: number = 0;
  isExpense: boolean = true;
  catColor: string = '#999999';

  build() {
    Row() {
      CategoryIcon({ icon: this.icon, color: this.catColor, size: 42 })

      Column() {
        Text(this.catName)
          .fontSize(15)
          .fontColor(this.theme.textPrimary)
          .fontWeight(FontWeight.Medium)
        if (this.note.length > 0) {
          Text(this.note)
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

      Text((this.isExpense ? '-' : '+') + ' ' + fmtMoney(this.amount))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.isExpense ? this.theme.expense : this.theme.income)
        .fontFeature('tnum')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
  }

  @StorageLink('themeName') themeName: string = 'dark';
  get theme(): ThemeColors {
    return getTheme(this.themeName);
  }
}

/**
 * 日期分组标题
 */
@Component
export struct DateHeader {
  @Prop label: string = '';

  build() {
    Text(this.label)
      .fontSize(12)
      .fontColor(this.theme.textSecondary)
      .fontWeight(FontWeight.Medium)
      .width('100%')
      .padding({ top: 16, bottom: 8 })
  }

  @StorageLink('themeName') themeName: string = 'dark';
  get theme(): ThemeColors {
    return getTheme(this.themeName);
  }
}
