#!/usr/bin/env node
/**
 * hvigor 命令行包装器 — 查找并执行 hvigor 构建入口
 * 首次请用 DevEco Studio 打开工程完成同步，之后即可用命令行构建。
 */
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const projectDir = path.join(__dirname, '..');
const nodeModules = path.join(projectDir, 'hvigor', 'node_modules');

function findEntry() {
  const candidates = [
    process.env.HVIGOR_HOME ? path.join(process.env.HVIGOR_HOME, 'bin', 'hvigorw.js') : null,
    path.join(nodeModules, '@ohos', 'hvigor', 'bin', 'hvigorw.js'),
    path.join(nodeModules, '@ohos', 'hvigor', 'bin', 'hvigor.js'),
    path.join(nodeModules, '@ohos', 'hvigor-ohos-plugin', 'bin', 'hvigorw.js'),
  ];
  for (const c of candidates) {
    if (c && fs.existsSync(c)) return c;
  }
  return null;
}

const entry = findEntry();
if (!entry) {
  console.error('[hvigor] 未找到 hvigor 入口。请先用 DevEco Studio 打开本项目完成同步。');
  process.exit(1);
}

const child = spawn(process.execPath, [entry, ...process.argv.slice(2)], {
  stdio: 'inherit',
  env: process.env,
});
child.on('close', (code) => process.exit(code === null ? 1 : code));
