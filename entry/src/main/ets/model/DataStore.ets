/**
 * 数据持久化层 — 基于 Preferences (轻量键值存储)
 * 所有数据以 JSON 字符串存于一个 preferences 文件中，简单可靠。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { formProvider, formBindingData } from '@kit.FormKit';
import { Category, Transaction, Budget, Template, DEFAULT_CATEGORIES, TxType } from './Models';

const STORE_NAME = 'ledger_store';
const KEY_CATEGORIES = 'categories';
const KEY_TRANSACTIONS = 'transactions';
const KEY_BUDGETS = 'budgets';
const KEY_CAT_BUDGETS = 'catBudgets';
const KEY_TEMPLATES = 'templates';
const KEY_THEME = 'theme';
const KEY_GLASS_ENABLED = 'glassEnabled';
const KEY_GLASS_BLUR = 'glassBlur';
const KEY_WALLPAPER_FILE = 'wallpaperFile';
const KEY_INIT = 'initialized';

/** 备份文件数据结构 */
interface BackupData {
  app: string;
  version: number;
  exportedAt: string;
  categories: Category[];
  transactions: Transaction[];
  budgets: Budget[];
}

/** 分类预算记录 */
interface CatBudget {
  categoryId: string;
  year: number;
  month: number;
  amount: number;
}

export class DataStore {
  private static instance: DataStore | null = null;
  private pref: preferences.Preferences | null = null;
  private ready: Promise<void> | null = null;
  private appContext: common.Context | null = null;

  private constructor() {}

  static getInstance(): DataStore {
    if (DataStore.instance === null) {
      DataStore.instance = new DataStore();
    }
    return DataStore.instance;
  }

  async init(context: common.Context): Promise<void> {
    if (this.ready !== null) {
      return this.ready;
    }
    this.ready = this.doInit(context);
    return this.ready;
  }

  /**
   * 供页面安全调用：返回已完成初始化（幂等）
   */
  async ensureInit(context: common.Context): Promise<void> {
    await this.init(context);
  }

  private async doInit(context: common.Context): Promise<void> {
    try {
      this.appContext = context;
      this.pref = await preferences.getPreferences(context, STORE_NAME);
      const inited = await this.getRaw(KEY_INIT);
      if (!inited) {
        // 首次启动：写入默认分类
        await this.setRaw(KEY_CATEGORIES, JSON.stringify(DEFAULT_CATEGORIES));
        await this.setRaw(KEY_TRANSACTIONS, JSON.stringify([]));
        await this.setRaw(KEY_BUDGETS, JSON.stringify([]));
        await this.setRaw(KEY_THEME, 'dark');
        await this.setRaw(KEY_INIT, '1');
      }
    } catch (e) {
      const msg = `[DataStore] init failed: ${JSON.stringify(e)}`;
      console.error(msg);
      throw new Error(msg);
    }
  }

  private async getRaw(key: string): Promise<string | null> {
    if (this.pref === null) return null;
    try {
      const v = await this.pref.get(key, '');
      if (v === undefined || v === null) return null;
      return v as string;
    } catch (e) {
      return null;
    }
  }

  private async setRaw(key: string, value: string): Promise<void> {
    if (this.pref === null) return;
    await this.pref.put(key, value);
    await this.pref.flush();
  }

  // ===== 分类 =====
  async getCategories(): Promise<Category[]> {
    const raw = await this.getRaw(KEY_CATEGORIES);
    if (!raw) return DEFAULT_CATEGORIES;
    try {
      return JSON.parse(raw) as Category[];
    } catch (e) {
      return DEFAULT_CATEGORIES;
    }
  }

  async saveCategory(cat: Category): Promise<void> {
    const cats = await this.getCategories();
    const idx = cats.findIndex(c => c.id === cat.id);
    if (idx >= 0) {
      cats[idx] = cat;
    } else {
      cats.push(cat);
    }
    await this.setRaw(KEY_CATEGORIES, JSON.stringify(cats));
  }

  async deleteCategory(id: string): Promise<void> {
    const cats = await this.getCategories();
    const filtered = cats.filter(c => c.id !== id);
    await this.setRaw(KEY_CATEGORIES, JSON.stringify(filtered));
  }

  // ===== 交易 =====
  async getTransactions(): Promise<Transaction[]> {
    const raw = await this.getRaw(KEY_TRANSACTIONS);
    if (!raw) return [];
    try {
      const list = JSON.parse(raw) as Transaction[];
      // 过滤无效记录（金额非数字等脏数据）
      return list.filter(t =>
        t && t.amount !== undefined && t.amount !== null && !isNaN(t.amount) && t.amount > 0
      );
    } catch (e) {
      return [];
    }
  }

  async addTransaction(tx: Transaction): Promise<void> {
    const list = await this.getTransactions();
    list.unshift(tx);
    await this.setRaw(KEY_TRANSACTIONS, JSON.stringify(list));
    await this.writeMonthlySummary();
  }

  async deleteTransaction(id: string): Promise<void> {
    const list = await this.getTransactions();
    const filtered = list.filter(t => t.id !== id);
    await this.setRaw(KEY_TRANSACTIONS, JSON.stringify(filtered));
    await this.writeMonthlySummary();
  }

  /**
   * 写入月度汇总文件（桌面小组件读取用）
   */
  async writeMonthlySummary(): Promise<void> {
    try {
      const now = new Date();
      const y = now.getFullYear();
      const m = now.getMonth() + 1;
      const txns = await this.getTransactionsByMonth(y, m);
      let income = 0;
      let expense = 0;
      for (const t of txns) {
        if (t.type === TxType.Income) income += t.amount;
        else expense += t.amount;
      }
      const summary: Record<string, string> = {
        'monthLabel': `${y}年${m}月`,
        'income': this.fmtMoney(income),
        'expense': this.fmtMoney(expense),
        'balance': this.fmtMoney(income - expense)
      };
      const ctx = this.appContext;
      if (ctx) {
        // 同步写文件（Form 读取要求同步可用）
        const path = `${ctx.filesDir}/monthly_summary.json`;
        try {
          const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);
          fs.writeSync(file.fd, JSON.stringify(summary));
          fs.closeSync(file);
          console.info(`[Summary] written: ${path}`);
        } catch (e) {
          console.error(`[Summary] write failed: ${JSON.stringify(e)}`);
        }
        // 主动推送桌面卡片刷新
        await this.pushToForms(summary);
      }
    } catch (e) {
      console.error(`[Summary] error: ${JSON.stringify(e)}`);
    }
  }

  // 推送数据到所有活跃的桌面卡片
  private async pushToForms(summary: Record<string, string>): Promise<void> {
    try {
      const infos = await formProvider.getPublishedRunningFormInfos();
      if (infos.length === 0) {
        console.info(`[Summary] no active forms`);
        return;
      }
      const obj: Record<string, Object> = {
        'monthLabel': summary['monthLabel'],
        'balance': summary['balance'],
        'income': summary['income'],
        'expense': summary['expense']
      };
      const binding = formBindingData.createFormBindingData(obj);
      for (const info of infos) {
        await formProvider.updateForm(info.formId, binding);
      }
      console.info(`[Summary] pushed to ${infos.length} forms`);
    } catch (e) {
      console.error(`[Summary] pushToForms failed: ${JSON.stringify(e)}`);
    }
  }

  fmtMoney(v: number): string {
    const neg = v < 0;
    const s = Math.abs(v).toFixed(2);
    return (neg ? '-' : '') + '¥ ' + s;
  }

  /**
   * 按月份获取交易
   */
  async getTransactionsByMonth(year: number, month: number): Promise<Transaction[]> {
    const all = await this.getTransactions();
    return all.filter(t => DateUtilInStore.inMonth(t.date, year, month));
  }

  // ===== 预算 =====
  async getBudget(year: number, month: number): Promise<Budget | null> {
    const raw = await this.getRaw(KEY_BUDGETS);
    if (!raw) return null;
    try {
      const list = JSON.parse(raw) as Budget[];
      const found = list.find(b => b.year === year && b.month === month);
      return found ? found : null;
    } catch (e) {
      return null;
    }
  }

  async saveBudget(budget: Budget): Promise<void> {
    const raw = await this.getRaw(KEY_BUDGETS);
    let list: Budget[] = [];
    if (raw) {
      try { list = JSON.parse(raw) as Budget[]; } catch (e) { list = []; }
    }
    const idx = list.findIndex(b => b.id === budget.id);
    if (idx >= 0) {
      list[idx] = budget;
    } else {
      list.push(budget);
    }
    await this.setRaw(KEY_BUDGETS, JSON.stringify(list));
  }

  // ===== 分类预算 =====
  /**
   * 获取某分类指定月份的预算（没有返回 0）
   */
  async getCategoryBudget(categoryId: string, year: number, month: number): Promise<number> {
    const raw = await this.getRaw(KEY_CAT_BUDGETS);
    if (!raw) return 0;
    try {
      const list = JSON.parse(raw) as CatBudget[];
      const found = list.find(b => b.categoryId === categoryId && b.year === year && b.month === month);
      return found ? found.amount : 0;
    } catch (e) {
      return 0;
    }
  }

  /**
   * 保存分类预算（0 = 删除预算）
   */
  async saveCategoryBudget(categoryId: string, year: number, month: number, amount: number): Promise<void> {
    const raw = await this.getRaw(KEY_CAT_BUDGETS);
    let list: CatBudget[] = [];
    if (raw) {
      try { list = JSON.parse(raw) as CatBudget[]; } catch (e) { list = []; }
    }
    // 删除旧的同键记录
    list = list.filter(b => !(b.categoryId === categoryId && b.year === year && b.month === month));
    if (amount > 0) {
      list.push({ categoryId: categoryId, year: year, month: month, amount: amount });
    }
    await this.setRaw(KEY_CAT_BUDGETS, JSON.stringify(list));
  }

  // ===== 主题 =====
  async getTheme(): Promise<string> {
    const raw = await this.getRaw(KEY_THEME);
    return raw ? raw : 'dark';
  }

  async saveTheme(theme: string): Promise<void> {
    await this.setRaw(KEY_THEME, theme);
  }

  // ===== 记账模板 =====
  async getTemplates(): Promise<Template[]> {
    const raw = await this.getRaw(KEY_TEMPLATES);
    if (!raw) return [];
    try {
      return JSON.parse(raw) as Template[];
    } catch (e) {
      return [];
    }
  }

  async saveTemplate(tpl: Template): Promise<void> {
    const list = await this.getTemplates();
    const idx = list.findIndex(t => t.id === tpl.id);
    if (idx >= 0) {
      list[idx] = tpl;
    } else {
      list.push(tpl);
    }
    await this.setRaw(KEY_TEMPLATES, JSON.stringify(list));
  }

  async deleteTemplate(id: string): Promise<void> {
    const list = await this.getTemplates();
    const filtered = list.filter(t => t.id !== id);
    await this.setRaw(KEY_TEMPLATES, JSON.stringify(filtered));
  }

  // ===== 玻璃模式 =====
  async getGlassEnabled(): Promise<boolean> {
    const raw = await this.getRaw(KEY_GLASS_ENABLED);
    return raw === '1';
  }

  async saveGlassEnabled(enabled: boolean): Promise<void> {
    await this.setRaw(KEY_GLASS_ENABLED, enabled ? '1' : '0');
  }

  async getGlassBlur(): Promise<number> {
    const raw = await this.getRaw(KEY_GLASS_BLUR);
    const v = parseFloat(raw ? raw : '');
    return (isNaN(v) || v <= 0) ? 30 : v;
  }

  async saveGlassBlur(blur: number): Promise<void> {
    await this.setRaw(KEY_GLASS_BLUR, blur.toString());
  }

  // 壁纸文件相对路径（应用沙箱内）
  async getWallpaperFile(): Promise<string> {
    const raw = await this.getRaw(KEY_WALLPAPER_FILE);
    return raw ? raw : '';
  }

  async saveWallpaperFile(fileName: string): Promise<void> {
    await this.setRaw(KEY_WALLPAPER_FILE, fileName);
  }

  /**
   * 统计某月的支出分类
   */
  async getExpenseStatsByMonth(year: number, month: number): Promise<Map<string, number>> {
    const txns = await this.getTransactionsByMonth(year, month);
    const map = new Map<string, number>();
    for (const t of txns) {
      if (t.type !== TxType.Expense) continue;
      const cur = map.get(t.categoryId);
      map.set(t.categoryId, (cur ? cur : 0) + t.amount);
    }
    return map;
  }

  // ===== 备份/恢复 =====
  /**
   * 导出全部数据为 JSON 字符串
   */
  async exportAll(): Promise<string> {
    const categories = await this.getCategories();
    const transactions = await this.getTransactions();
    const budgetsRaw = await this.getRaw(KEY_BUDGETS);
    let budgets: Budget[] = [];
    if (budgetsRaw) {
      try { budgets = JSON.parse(budgetsRaw) as Budget[]; } catch (e) { budgets = []; }
    }
    const data: BackupData = {
      app: 'HarmonyLedger',
      version: 1,
      exportedAt: new Date().toISOString(),
      categories: categories,
      transactions: transactions,
      budgets: budgets
    };
    return JSON.stringify(data);
  }

  /**
   * 从 JSON 字符串恢复全部数据（覆盖现有）
   */
  async importAll(json: string): Promise<boolean> {
    try {
      const parsed = JSON.parse(json) as object;
      if (!parsed) return false;
      const data = parsed as BackupData;
      if (data.app !== 'HarmonyLedger') return false;
      const categories: Category[] = data.categories || [];
      const transactions: Transaction[] = data.transactions || [];
      const budgets: Budget[] = data.budgets || [];
      // 过滤无效交易
      const validTx = transactions.filter(t =>
        t && t.amount !== undefined && !isNaN(t.amount) && t.amount > 0 && t.date && t.categoryId
      );
      await this.setRaw(KEY_CATEGORIES, JSON.stringify(categories));
      await this.setRaw(KEY_TRANSACTIONS, JSON.stringify(validTx));
      await this.setRaw(KEY_BUDGETS, JSON.stringify(budgets));
      return true;
    } catch (e) {
      return false;
    }
  }
}

/**
 * 工具类（避免循环引用 Models 内 DateUtil 不便导出）
 */
class DateUtilInStore {
  static inMonth(dateStr: string, y: number, m: number): boolean {
    return dateStr.startsWith(`${y}-${m < 10 ? '0' + m.toString() : m.toString()}`);
  }
}
