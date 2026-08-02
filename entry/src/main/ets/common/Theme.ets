/**
 * 主题系统 — 深色/浅色设计令牌
 * 通过 @StorageLink 全局同步主题状态
 */

export interface ThemeColors {
  bgPrimary: string;
  bgCard: string;
  bgElevated: string;
  bgInput: string;
  border: string;
  borderLight: string;
  textPrimary: string;
  textSecondary: string;
  textMuted: string;
  accent: string;
  accentHover: string;
  accentMuted: string;
  income: string;
  incomeBg: string;
  expense: string;
  expenseBg: string;
  danger: string;
  warning: string;
  shadow: string;
  navBg: string;
  balanceBg: string;
}

export const DARK_THEME: ThemeColors = {
  bgPrimary: '#0F0F0F',
  bgCard: '#1A1A1A',
  bgElevated: '#222222',
  bgInput: '#1E1E1E',
  border: '#2A2A2A',
  borderLight: '#222222',
  textPrimary: '#F5F5F5',
  textSecondary: '#999999',
  textMuted: '#666666',
  accent: '#D4A574',
  accentHover: '#C9975E',
  accentMuted: 'rgba(212,165,116,0.12)',
  income: '#7DCEA0',
  incomeBg: 'rgba(125,206,160,0.10)',
  expense: '#E88D7D',
  expenseBg: 'rgba(232,141,125,0.10)',
  danger: '#E06060',
  warning: '#E8C76D',
  shadow: 'rgba(0,0,0,0.40)',
  navBg: '#0F0F0F',
  balanceBg: '#1A1A1A'
};

export const LIGHT_THEME: ThemeColors = {
  bgPrimary: '#F5F5F5',
  bgCard: '#FFFFFF',
  bgElevated: '#FFFFFF',
  bgInput: '#F0F0F0',
  border: '#E8E8E8',
  borderLight: '#F0F0F0',
  textPrimary: '#1A1A1A',
  textSecondary: '#777777',
  textMuted: '#AAAAAA',
  accent: '#B48250',
  accentHover: '#A07440',
  accentMuted: 'rgba(180,130,80,0.10)',
  income: '#4CAF7D',
  incomeBg: 'rgba(76,175,125,0.10)',
  expense: '#D96B5A',
  expenseBg: 'rgba(217,107,90,0.10)',
  danger: '#D94F4F',
  warning: '#C9A44B',
  shadow: 'rgba(0,0,0,0.08)',
  navBg: '#F5F5F5',
  balanceBg: '#FFFFFF'
};

export function getTheme(themeName: string | undefined): ThemeColors {
  if (themeName === 'light') return LIGHT_THEME;
  return DARK_THEME;
}

/**
 * 玻璃版主题：背景透明（显示壁纸照片），卡片半透明白（玻璃质感）
 * 调用方负责给卡片组件加 backdropBlur
 * 注意：ArkTS 不支持对象展开，字段全部显式写出
 */
export function getGlassTheme(themeName: string | undefined): ThemeColors {
  const light = themeName === 'light';
  return {
    bgPrimary: 'rgba(0,0,0,0)',
    bgCard: 'rgba(255,255,255,0.12)',
    bgElevated: 'rgba(255,255,255,0.18)',
    bgInput: 'rgba(255,255,255,0.10)',
    border: 'rgba(255,255,255,0.25)',
    borderLight: 'rgba(255,255,255,0.15)',
    textPrimary: light ? '#1A1A1A' : '#F5F5F5',
    textSecondary: light ? '#666666' : '#CCCCCC',
    textMuted: light ? '#999999' : '#888888',
    accent: light ? '#B48250' : '#D4A574',
    accentHover: light ? '#A07440' : '#C9975E',
    accentMuted: 'rgba(212,165,116,0.20)',
    income: light ? '#4CAF7D' : '#7DCEA0',
    incomeBg: 'rgba(125,206,160,0.20)',
    expense: light ? '#D96B5A' : '#E88D7D',
    expenseBg: 'rgba(232,141,125,0.20)',
    danger: '#E06060',
    warning: '#E8C76D',
    shadow: 'rgba(0,0,0,0.30)',
    navBg: 'rgba(15,15,15,0.55)',
    balanceBg: 'rgba(255,255,255,0.12)'
  };
}

/**
 * 金额格式化
 */
export function fmtMoney(amount: number): string {
  const neg = amount < 0;
  const abs = Math.abs(amount);
  const s = abs.toFixed(2);
  return (neg ? '-' : '') + '¥ ' + s;
}
