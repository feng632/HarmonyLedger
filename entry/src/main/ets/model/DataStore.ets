/**
 * 数据持久化层 — 基于 Preferences (轻量键值存储)
 * 所有数据以 JSON 字符串存于一个 preferences 文件中，简单可靠。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Category, Transaction, Budget, DEFAULT_CATEGORIES, TxType } from './Models';

const STORE_NAME = 'ledger_store';
const KEY_CATEGORIES = 'categories';
const KEY_TRANSACTIONS = 'transactions';
const KEY_BUDGETS = 'budgets';
const KEY_THEME = 'theme';
const KEY_INIT = 'initialized';

export class DataStore {
  private static instance: DataStore | null = null;
  private pref: preferences.Preferences | null = null;
  private ready: Promise<void> | null = null;

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
      return JSON.parse(raw) as Transaction[];
    } catch (e) {
      return [];
    }
  }

  async addTransaction(tx: Transaction): Promise<void> {
    const list = await this.getTransactions();
    list.unshift(tx);
    await this.setRaw(KEY_TRANSACTIONS, JSON.stringify(list));
  }

  async deleteTransaction(id: string): Promise<void> {
    const list = await this.getTransactions();
    const filtered = list.filter(t => t.id !== id);
    await this.setRaw(KEY_TRANSACTIONS, JSON.stringify(filtered));
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

  // ===== 主题 =====
  async getTheme(): Promise<string> {
    const raw = await this.getRaw(KEY_THEME);
    return raw ? raw : 'dark';
  }

  async saveTheme(theme: string): Promise<void> {
    await this.setRaw(KEY_THEME, theme);
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
}

/**
 * 工具类（避免循环引用 Models 内 DateUtil 不便导出）
 */
class DateUtilInStore {
  static inMonth(dateStr: string, y: number, m: number): boolean {
    return dateStr.startsWith(`${y}-${m < 10 ? '0' + m.toString() : m.toString()}`);
  }
}
