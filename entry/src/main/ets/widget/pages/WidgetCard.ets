/**
 * 桌面小组件 UI — 月度余额卡片（2x2）
 * 数据由 FormAbility 通过 FormBindingData 注入
 */
@Entry
@Component
struct WidgetCard {
  @LocalStorageProp('monthLabel') monthLabel: string = '';
  @LocalStorageProp('balance') balance: string = '--';
  @LocalStorageProp('income') income: string = '--';
  @LocalStorageProp('expense') expense: string = '--';

  build() {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: {}
    }) {
      Column() {
        // 月份标签
        Row() {
          Text(this.monthLabel)
            .fontSize(12)
            .fontColor('#999999')
            .fontWeight(FontWeight.Medium)
          Blank()
        }
        .width('100%')

        // 余额
        Text(this.balance)
          .fontSize(24)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F5F5F5')
          .fontFeature('tnum')
          .width('100%')
          .textAlign(TextAlign.Start)
          .margin({ top: 8 })

        // 收入/支出
        Row() {
          Text('收 ' + this.income)
            .fontSize(11)
            .fontColor('#7DCEA0')
          Blank()
          Text('支 ' + this.expense)
            .fontSize(11)
            .fontColor('#E88D7D')
        }
        .width('100%')
        .margin({ top: 10 })
      }
      .width('100%')
      .height('100%')
      .padding(16)
      .backgroundColor('#1A1A1A')
      .borderRadius(20)
    }
    .width('100%')
    .height('100%')
  }
}
