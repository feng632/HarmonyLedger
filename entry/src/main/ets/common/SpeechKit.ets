/**
 * 语音记账 — 语音识别 + 中文文本解析
 * 使用 @kit.CoreSpeechKit 在线识别 + @kit.AudioKit 录音
 */
import { speechRecognizer } from '@kit.CoreSpeechKit';
import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'SpeechKit';

/**
 * 解析结果：从语音文本中提取金额和分类
 */
export interface SpeechParseResult {
  amount: number;       // 0 = 未识别到金额
  categoryId: string;   // '' = 未匹配分类
  categoryName: string; // 匹配到的分类名（用于提示）
  raw: string;          // 原始语音文本
}

/** 分类匹配输入 */
export interface SpeechCategory {
  id: string;
  name: string;
  icon: string;
}

/** 分类匹配结果 */
export interface SpeechCatMatch {
  id: string;
  name: string;
}

/** 关键词映射 */
interface KeywordMap {
  keywords: string[];
  name: string;
}

/**
 * 中文金额解析：支持阿拉伯数字和中文数字
 * "八块" → 8, "12.5元" → 12.5, "一百二十" → 120
 */
export function parseChineseAmount(text: string): number {
  // 1. 直接阿拉伯数字 + 单位
  const numMatch = text.match(/(\d+(?:\.\d+)?)\s*(?:元|块|块钱|毛|分)?/);
  if (numMatch) {
    return Math.round(parseFloat(numMatch[1]) * 100) / 100;
  }

  // 2. 中文数字（支持 十百千万 组合）
  const chineseNum = parseChineseNumber(text);
  if (chineseNum > 0) {
    return chineseNum;
  }
  return 0;
}

// 中文数字 → 阿拉伯数字
function parseChineseNumber(text: string): number {
  const digits: Record<string, number> = {
    '零': 0, '一': 1, '二': 2, '两': 2, '三': 3, '四': 4,
    '五': 5, '六': 6, '七': 7, '八': 8, '九': 9
  };
  const units: Record<string, number> = {
    '十': 10, '百': 100, '千': 1000, '万': 10000
  };

  // 提取数字部分（"早餐八块" → "八"）
  const numPart = text.match(/[零一二两三四五六七八九十百千万]+/);
  if (!numPart) return 0;
  const s = numPart[0];

  // 十位处理："十二" = 12, "十" = 10
  if (s === '十') return 10;
  if (s.startsWith('十')) {
    return 10 + (digits[s[1]] || 0);
  }

  let total = 0;
  let current = 0;
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (digits[ch] !== undefined) {
      current = digits[ch];
    } else if (units[ch] !== undefined) {
      const u = units[ch];
      if (current === 0) current = 1; // "百" 前无数 → 一百
      total += current * u;
      current = 0;
    }
  }
  total += current;
  return total;
}

/**
 * 分类匹配：关键词 → 分类 ID
 */
export function matchCategory(text: string, cats: SpeechCategory[]): SpeechCatMatch {
  // 常见关键词 → 分类名
  const keywordMap: KeywordMap[] = [
    { keywords: ['早餐', '午饭', '晚餐', '吃饭', '外卖', '奶茶', '咖啡', '食堂', '面条', '火锅', '烧烤', '肯德基', '麦当劳'], name: '餐饮' },
    { keywords: ['地铁', '公交', '打车', '出租', '滴滴', '高铁', '火车', '机票', '加油', '停车', '单车'], name: '交通' },
    { keywords: ['购物', '买', '淘宝', '京东', '拼多多', '衣服', '鞋', '超市'], name: '购物' },
    { keywords: ['电影', '游戏', '唱歌', 'ktv', '门票', '会员'], name: '娱乐' },
    { keywords: ['房租', '房贷', '物业', '水费', '电费', '燃气'], name: '住房' },
    { keywords: ['药', '医院', '看病', '挂号'], name: '医疗' },
    { keywords: ['书', '课程', '学费', '培训'], name: '学习' },
    { keywords: ['工资', '薪水', '发工资'], name: '工资' },
    { keywords: ['红包', '奖金', '压岁钱'], name: '红包' },
  ];

  const lower = text.toLowerCase();
  for (const map of keywordMap) {
    for (const kw of map.keywords) {
      if (lower.includes(kw)) {
        // 在用户分类中找匹配
        const cat = cats.find(c => c.name === map.name);
        if (cat) return { id: cat.id, name: cat.name };
        break;
      }
    }
  }
  return { id: '', name: '' };
}

/**
 * 从语音文本解析记账信息
 */
export function parseSpeech(text: string, cats: SpeechCategory[]): SpeechParseResult {
  const amount = parseChineseAmount(text);
  const catMatch = matchCategory(text, cats);
  return {
    amount: amount,
    categoryId: catMatch.id,
    categoryName: catMatch.name,
    raw: text
  };
}

/**
 * 语音识别引擎封装（录音 + 喂音频 + 识别）
 */
export class SpeechRecognizer {
  private engine: speechRecognizer.SpeechRecognitionEngine | null = null;
  private sessionId: string = '';
  private onResultCallback: ((text: string) => void) | null = null;
  private capturer: audio.AudioCapturer | null = null;
  private capturing: boolean = false;
  private resultText: string = '';
  private lastResultTime: number = 0;

  async init(): Promise<boolean> {
    try {
      this.sessionId = 'session_' + Date.now().toString(36);
      const params: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: 1,
        extraParams: {
          'kaleidoscope': ''
        }
      };
      this.engine = await speechRecognizer.createEngine(params);
      this.engine.setListener({
        onStart: (sessionId: string, eventMessage: string) => {
          hilog.info(0x0000, TAG, `onStart: ${sessionId}`);
        },
        onEvent: (sessionId: string, eventCode: number, eventMessage: string) => {
          hilog.info(0x0000, TAG, `onEvent: ${eventCode} ${eventMessage}`);
        },
        onResult: (sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
          hilog.info(0x0000, TAG, `onResult: ${result.result} isFinal=${result.isFinal}`);
          this.resultText = result.result;
          this.lastResultTime = Date.now();
          if (result.isFinal && this.onResultCallback) {
            this.onResultCallback(result.result);
          }
        },
        onComplete: (sessionId: string, eventMessage: string) => {
          hilog.info(0x0000, TAG, `onComplete`);
          // 若完成时已有结果但没触发 isFinal，兜底回调
          if (this.resultText.length > 0 && this.onResultCallback) {
            this.onResultCallback(this.resultText);
          }
          this.stopCapturing();
        },
        onError: (sessionId: string, errorCode: number, errorMessage: string) => {
          hilog.error(0x0000, TAG, `onError: ${errorCode} ${errorMessage}`);
          this.stopCapturing();
          if (this.onResultCallback) {
            this.onResultCallback('');
          }
        }
      });
      return true;
    } catch (e) {
      hilog.error(0x0000, TAG, `init failed: ${JSON.stringify(e)}`);
      return false;
    }
  }

  /**
   * 开始识别（录音 + 喂音频）
   */
  async start(onResult: (text: string) => void): Promise<void> {
    this.onResultCallback = onResult;
    this.resultText = '';
    if (!this.engine) {
      const ok = await this.init();
      if (!ok) {
        onResult('');
        return;
      }
    }
    this.doStart();
    await this.startCapturing();
  }

  private doStart(): void {
    try {
      const params: speechRecognizer.StartParams = {
        sessionId: this.sessionId,
        audioInfo: {
          audioType: 'pcm',
          sampleRate: 16000,
          soundChannel: 1,
          sampleBit: 16
        }
      };
      this.engine!.startListening(params);
      hilog.info(0x0000, TAG, `startListening`);
    } catch (e) {
      hilog.error(0x0000, TAG, `start failed: ${JSON.stringify(e)}`);
      if (this.onResultCallback) this.onResultCallback('');
    }
  }

  // 录音并实时喂给识别引擎
  private async startCapturing(): Promise<void> {
    try {
      const options: audio.AudioCapturerOptions = {
        streamInfo: {
          samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
          channels: audio.AudioChannel.CHANNEL_1,
          sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
          encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
        },
        capturerInfo: {
          source: audio.SourceType.SOURCE_TYPE_MIC,
          capturerFlags: 0
        }
      };
      this.capturer = await audio.createAudioCapturer(options);
      await this.capturer.start();

      this.capturing = true;
      const bufferSize = 1280; // 引擎要求的音频块大小
      const readLoop = async (): Promise<void> => {
        while (this.capturing && this.capturer) {
          try {
            const buf = await this.capturer.read(bufferSize, true);
            if (this.engine && buf) {
              this.engine.writeAudio(this.sessionId, new Uint8Array(buf));
            }
          } catch (e) {
            hilog.error(0x0000, TAG, `read failed: ${JSON.stringify(e)}`);
            break;
          }
        }
      };
      readLoop();
      hilog.info(0x0000, TAG, `capturing started`);
    } catch (e) {
      hilog.error(0x0000, TAG, `capture failed: ${JSON.stringify(e)}`);
    }
  }

  private stopCapturing(): void {
    this.capturing = false;
    try {
      if (this.capturer) {
        this.capturer.stop();
        this.capturer.release();
        this.capturer = null;
      }
    } catch (e) {
      // 忽略
    }
  }

  shutdown(): void {
    this.stopCapturing();
    try {
      if (this.engine) {
        this.engine.shutdown();
        this.engine = null;
      }
    } catch (e) {
      // 忽略
    }
  }
}
