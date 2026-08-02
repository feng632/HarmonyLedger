/**
 * 预算提醒 — 记账后检查预算，超支时发系统通知
 */
import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { DataStore } from '../model/DataStore';

const store = DataStore.getInstance();

/**
 * 检查并发送预算超支通知
 * 记账/删除后调用：检查月度预算 + 分类预算，超 80% 提示、超 100% 警告
 */
export async function checkAndNotifyBudget(context: common.Context): Promise<void> {
  try {
    // 请求通知授权（首次会弹系统对话框，之后静默）
    await requestNotifyPermission(context);
    await doCheck(context);
  } catch (e) {
    console.error(`[BudgetAlert] check failed: ${JSON.stringify(e)}`);
  }
}

// 请求通知授权
async function requestNotifyPermission(context: common.Context): Promise<void> {
  try {
    const abilityContext = context as common.UIAbilityContext;
    await notificationManager.requestEnableNotification(abilityContext);
    console.info(`[BudgetAlert] notification permission requested`);
  } catch (e) {
    // 已授权时调用会报错，忽略
    console.info(`[BudgetAlert] permission request skipped: ${JSON.stringify(e)}`);
  }
}

// 实际检查逻辑
async function doCheck(context: common.Context): Promise<void> {
  const now = new Date();
  const y = now.getFullYear();
  const m = now.getMonth() + 1;

  // 本月支出
  const txns = await store.getTransactionsByMonth(y, m);
  let totalSpent = 0;
  const catSpent = new Map<string, number>();
  for (const t of txns) {
    if (t.type !== 'expense') continue;
    totalSpent += t.amount;
    const cur = catSpent.get(t.categoryId);
    catSpent.set(t.categoryId, (cur ? cur : 0) + t.amount);
  }

  // 月度预算检查
  const monthBudget = await store.getBudget(y, m);
  if (monthBudget && monthBudget.amount > 0) {
    const pct = totalSpent / monthBudget.amount * 100;
    if (pct >= 100) {
      await publishBudgetNotice(context, '月度预算已超支', `本月已花 ¥${fmt(totalSpent)}，超出预算 ¥${fmt(totalSpent - monthBudget.amount)}`);
    } else if (pct >= 80) {
      await publishBudgetNotice(context, '月度预算即将超支', `本月已花 ¥${fmt(totalSpent)}（${Math.round(pct)}%），注意控制开支`);
    }
  }

  // 分类预算检查
  const cats = await store.getCategories();
  for (const cat of cats) {
    if (cat.type !== 'expense') continue;
    const budget = await store.getCategoryBudget(cat.id, y, m);
    if (budget <= 0) continue;
    const spent = catSpent.get(cat.id) || 0;
    const pct = spent / budget * 100;
    if (pct >= 100) {
      await publishBudgetNotice(context, `${cat.name}预算已超支`, `${cat.name}本月已花 ¥${fmt(spent)}，超出 ¥${fmt(spent - budget)}`);
    } else if (pct >= 80) {
      await publishBudgetNotice(context, `${cat.name}预算即将超支`, `${cat.name}本月已花 ¥${fmt(spent)}（${Math.round(pct)}%）`);
    }
  }
}

// 发送单条通知（相同内容会替换，避免刷屏）
async function publishBudgetNotice(context: common.Context, title: string, text: string): Promise<void> {
  try {
    const request: notificationManager.NotificationRequest = {
      id: 1001,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: text
        }
      },
      deliveryTime: new Date().getTime()
    };
    await notificationManager.publish(request);
    console.info(`[BudgetAlert] notified: ${title}`);
  } catch (e) {
    console.error(`[BudgetAlert] publish failed: ${JSON.stringify(e)}`);
  }
}

function fmt(v: number): string {
  return Math.round(v * 100) / 100 + '';
}
