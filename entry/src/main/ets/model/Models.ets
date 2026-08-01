/**
 * 交易记录模型
 */
export enum TxType {
  Expense = 'expense',
  Income = 'income'
}

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  type: TxType;
  isDefault: boolean;
}

export interface Transaction {
  id: string;
  type: TxType;
  amount: number;
  categoryId: string;
  note: string;
  date: string; // yyyy-MM-dd
  createdAt: number;
}

export interface Budget {
  id: string;      // budget_yyyy-MM
  amount: number;
  year: number;
  month: number;
}

export interface MonthSummary {
  income: number;
  expense: number;
  balance: number;
}

export interface CategoryStat {
  categoryId: string;
  name: string;
  icon: string;
  color: string;
  amount: number;
}

export const CATEGORY_COLORS: string[] = [
  '#E88D7D', '#7DCEA0', '#7DBCEA', '#C9A0DC', '#F0B37B',
  '#8DBDA0', '#E8998D', '#A0C8E8', '#B8C97D', '#E8A87D',
  '#6DB5C4', '#D4A574', '#E8C76D', '#7DB8A0', '#999999'
];

/**
 * 默认分类
 */
export const DEFAULT_CATEGORIES: Category[] = [
  // 支出
  { id: 'cat_food', name: '餐饮', icon: '🍜', color: '#E88D7D', type: TxType.Expense, isDefault: true },
  { id: 'cat_transport', name: '交通', icon: '🚗', color: '#7DBCEA', type: TxType.Expense, isDefault: true },
  { id: 'cat_shopping', name: '购物', icon: '🛍️', color: '#C9A0DC', type: TxType.Expense, isDefault: true },
  { id: 'cat_entertain', name: '娱乐', icon: '🎬', color: '#F0B37B', type: TxType.Expense, isDefault: true },
  { id: 'cat_housing', name: '住房', icon: '🏠', color: '#8DBDA0', type: TxType.Expense, isDefault: true },
  { id: 'cat_health', name: '医疗', icon: '💊', color: '#E8998D', type: TxType.Expense, isDefault: true },
  { id: 'cat_education', name: '学习', icon: '📚', color: '#A0C8E8', type: TxType.Expense, isDefault: true },
  { id: 'cat_other_exp', name: '其他', icon: '📌', color: '#999999', type: TxType.Expense, isDefault: true },
  // 收入
  { id: 'cat_salary', name: '工资', icon: '💰', color: '#7DCEA0', type: TxType.Income, isDefault: true },
  { id: 'cat_freelance', name: '兼职', icon: '💻', color: '#6DB5C4', type: TxType.Income, isDefault: true },
  { id: 'cat_invest', name: '投资', icon: '📈', color: '#B8C97D', type: TxType.Income, isDefault: true },
  { id: 'cat_gift_inc', name: '红包', icon: '🧧', color: '#E8A87D', type: TxType.Income, isDefault: true },
  { id: 'cat_other_inc', name: '其他', icon: '📌', color: '#999999', type: TxType.Income, isDefault: true }
];

/**
 * 日期工具
 */
export class DateUtil {
  static pad2(n: number): string {
    return n < 10 ? '0' + n.toString() : n.toString();
  }

  static formatDate(y: number, m: number, d: number): string {
    return `${y}-${DateUtil.pad2(m)}-${DateUtil.pad2(d)}`;
  }

  static today(): string {
    const now = new Date();
    return DateUtil.formatDate(now.getFullYear(), now.getMonth() + 1, now.getDate());
  }

  static weekdayOf(dateStr: string): string {
    const parts = dateStr.split('-');
    const d = new Date(parseInt(parts[0]), parseInt(parts[1]) - 1, parseInt(parts[2]));
    const weeks = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return weeks[d.getDay()];
  }

  static formatDisplay(dateStr: string): string {
    const parts = dateStr.split('-');
    return `${parseInt(parts[1])}月${parseInt(parts[2])}日 ${DateUtil.weekdayOf(dateStr)}`;
  }

  static monthPrefix(y: number, m: number): string {
    return `${y}-${DateUtil.pad2(m)}`;
  }

  static inMonth(dateStr: string, y: number, m: number): boolean {
    return dateStr.startsWith(DateUtil.monthPrefix(y, m));
  }
}

/**
 * 金额格式化
 */
export function formatCurrency(amount: number): string {
  const neg = amount < 0;
  const abs = Math.abs(amount);
  const fixed = abs.toFixed(2);
  return (neg ? '-¥ ' : '¥ ') + fixed;
}

/**
 * 生成唯一 ID
 */
export function genId(): string {
  return Date.now().toString(36) + Math.floor(Math.random() * 0xffffffff).toString(36);
}
