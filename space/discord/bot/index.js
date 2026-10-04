import { Client, GatewayIntentBits, Partials } from 'discord.js';
import { spawn } from 'child_process';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// private/.env.discord からトークン読み込み
const envPath = path.resolve(__dirname, '../../../private/.env.discord');
if (fs.existsSync(envPath)) {
  dotenv.config({ path: envPath });
} else {
  dotenv.config();
}

let token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
  console.error('Error: DISCORD_BOT_TOKEN is not set');
  process.exit(1);
}
if (token.startsWith('Bot ')) {
  token = token.slice(4).trim();
}

const WORKSPACE_ROOT = path.resolve(__dirname, '../../..');

const client = new Client({
  intents: [
    GatewayIntentBits.Guilds,
    GatewayIntentBits.GuildMessages,
    GatewayIntentBits.MessageContent,
  ],
  partials: [Partials.Channel, Partials.Message]
});

// Discordチャット用にプロンプトを簡潔化するラッパー
function wrapPromptForDiscord(prompt) {
  return `[Discordチャット用の回答制約]
Discordでのチャット会話です。
- 長文レポートや冗長な前置きは禁止します。
- 要点を2〜5行程度の簡潔な箇条書きまたは短い文章で回答してください。
- 必要最小限の情報（結論、重要な数値・日時・URLなど）のみを伝えてください。

【指示】
${prompt}`;
}

// agy CLI をサブプロセスとして実行する関数 (リトライ対応)
async function executeAgyWithRetry(prompt, conversationId = null, effort = 'low', maxRetries = 2) {
  const formattedPrompt = wrapPromptForDiscord(prompt);

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await executeAgyOnce(formattedPrompt, conversationId, effort);
    } catch (err) {
      const errMsg = err.message || '';
      const isRetryable = errMsg.includes('network issue') || 
                          errMsg.includes('timed out') || 
                          errMsg.includes('retryable":true') ||
                          errMsg.includes('connection reset');

      if (isRetryable && attempt < maxRetries) {
        console.warn(`[agy] Attempt ${attempt} failed with retryable network error. Retrying in 2s...`);
        await new Promise(r => setTimeout(r, 2000));
        continue;
      }
      throw err;
    }
  }
}

function executeAgyOnce(prompt, conversationId = null, effort = 'low') {
  return new Promise((resolve, reject) => {
    const args = [
      '--print', prompt,
      '--output-format', 'json',
      '--dangerously-skip-permissions',
      '--effort', effort
    ];

    if (conversationId) {
      args.push('--conversation', conversationId);
    }

    const userHome = process.env.HOME || '';
    const extraPaths = [
      `${userHome}/.local/bin`,
      '/usr/local/bin',
      '/opt/homebrew/bin',
      '/usr/bin',
      '/bin'
    ].filter(Boolean).join(':');

    const env = {
      ...process.env,
      PATH: `${extraPaths}:${process.env.PATH || ''}`
    };

    console.log(`[agy] Executing in ${WORKSPACE_ROOT}: agy (effort: ${effort})`);

    const proc = spawn('agy', args, {
      cwd: WORKSPACE_ROOT,
      env
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (chunk) => {
      stdout += chunk.toString();
    });

    proc.stderr.on('data', (chunk) => {
      stderr += chunk.toString();
    });

    proc.on('close', (code) => {
      if (code !== 0) {
        console.error(`[agy] Process exited with code ${code}. Stderr: ${stderr}`);
        return reject(new Error(stderr || `agy exited with code ${code}`));
      }

      try {
        const json = JSON.parse(stdout);
        resolve(json);
      } catch (err) {
        console.error(`[agy] Failed to parse JSON stdout: ${stdout}`);
        resolve({ response: stdout, status: 'RAW' });
      }
    });

    proc.on('error', (err) => {
      console.error(`[agy] Failed to spawn agy:`, err);
      reject(err);
    });
  });
}

// 2000文字制限に合わせて分割送信するヘルパー
function chunkText(text, limit = 1900) {
  const chunks = [];
  let remaining = text;
  while (remaining.length > limit) {
    let index = remaining.lastIndexOf('\n', limit);
    if (index === -1) index = limit;
    chunks.push(remaining.slice(0, index));
    remaining = remaining.slice(index).trimStart();
  }
  if (remaining.length > 0) {
    chunks.push(remaining);
  }
  return chunks;
}

client.once('ready', () => {
  console.log(`Logged in as ${client.user.tag} (ID: ${client.user.id})`);
  console.log(`Ready to handle /agy slash commands and @${client.user.username} mentions.`);
});

// 1. スラッシュコマンド (/agy) ハンドラ
client.on('interactionCreate', async (interaction) => {
  if (!interaction.isChatInputCommand()) return;

  if (interaction.commandName === 'agy') {
    let prompt = interaction.options.getString('prompt') || '';
    // もしユーザーが "prompt:..." と二重に入力してしまった場合のサニタイズ
    if (prompt.startsWith('prompt:')) {
      prompt = prompt.slice(7).trim();
    }
    const effort = interaction.options.getString('effort') || 'low';

    // 3秒ルール回避のため即座に応答を保留
    await interaction.deferReply();

    try {
      console.log(`[Interaction] Received /agy prompt: "${prompt}" (effort: ${effort})`);
      const result = await executeAgyWithRetry(prompt, null, effort);
      const replyText = result.response || '(応答が空でした)';

      const chunks = chunkText(replyText);
      await interaction.editReply(chunks[0]);

      for (let i = 1; i < chunks.length; i++) {
        await interaction.followUp(chunks[i]);
      }
    } catch (err) {
      console.error('[Interaction] Error executing agy:', err);
      let userError = 'タスクの実行中にエラーが発生しました。';
      if (err.message && (err.message.includes('network issue') || err.message.includes('timed out'))) {
        userError = '一時的なネットワーク通信タイムアウトが発生しました。数秒置いて再度お試しください。';
      }
      await interaction.editReply(userError);
    }
  }
});

// 2. メンション (@mcp) ハンドラ
client.on('messageCreate', async (message) => {
  if (message.author.bot) return;

  if (message.mentions.has(client.user)) {
    // メンションを取り除いてプロンプトを抽出
    const rawContent = message.content || '';
    let prompt = rawContent.replace(new RegExp(`<@!?${client.user.id}>`, 'g'), '').trim();

    if (!prompt) {
      await message.reply('メッセージ内容を取得できませんでした。スラッシュコマンド `/agy` をご利用いただくか、Developer Portal で Message Content Intent を有効化してください。');
      return;
    }

    console.log(`[Mention] Received from ${message.author.tag}: "${prompt}"`);

    // 入力中 (typing) を維持
    await message.channel.sendTyping();
    const typingInterval = setInterval(() => {
      message.channel.sendTyping().catch(() => {});
    }, 8000);

    try {
      const result = await executeAgyWithRetry(prompt, null, 'low');
      clearInterval(typingInterval);

      const replyText = result.response || '(応答が空でした)';
      const chunks = chunkText(replyText);

      await message.reply(chunks[0]);
      for (let i = 1; i < chunks.length; i++) {
        await message.channel.send(chunks[i]);
      }
    } catch (err) {
      clearInterval(typingInterval);
      console.error('[Mention] Error executing agy:', err);
      let userError = 'タスクの実行中にエラーが発生しました。';
      if (err.message && (err.message.includes('network issue') || err.message.includes('timed out'))) {
        userError = '一時的なネットワーク通信タイムアウトが発生しました。数秒置いて再度お試しください。';
      }
      await message.reply(userError);
    }
  }
});

client.login(token);
