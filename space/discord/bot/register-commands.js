import { REST, Routes, SlashCommandBuilder } from 'discord.js';
import dotenv from 'dotenv';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// private/.env.discord を読み込み
const envPath = path.resolve(__dirname, '../../../private/.env.discord');
if (fs.existsSync(envPath)) {
  dotenv.config({ path: envPath });
} else {
  dotenv.config();
}

let token = process.env.DISCORD_BOT_TOKEN;
if (!token) {
  console.error('Error: DISCORD_BOT_TOKEN is not set in environment or private/.env.discord');
  process.exit(1);
}
// Clean token prefix if "Bot " is prepended
if (token.startsWith('Bot ')) {
  token = token.slice(4).trim();
}

const CLIENT_ID = '1555181587929505802';
const GUILD_ID = '1034269547403943989';

const commands = [
  new SlashCommandBuilder()
    .setName('agy')
    .setDescription('Antigravity CLI (agy) に指示を出してタスクを実行します')
    .addStringOption(option =>
      option.setName('prompt')
        .setDescription('指示・プロンプト')
        .setRequired(true)
    )
    .addStringOption(option =>
      option.setName('effort')
        .setDescription('推論レベル (low, medium, high, max)')
        .setRequired(false)
        .addChoices(
          { name: 'low (高速・推奨)', value: 'low' },
          { name: 'medium (標準)', value: 'medium' },
          { name: 'high (詳細)', value: 'high' },
          { name: 'max (最深)', value: 'max' }
        )
    )
].map(command => command.toJSON());

const rest = new REST({ version: '10' }).setToken(token);

(async () => {
  try {
    console.log(`Started refreshing ${commands.length} application (/) commands for guild ${GUILD_ID}...`);
    const data = await rest.put(
      Routes.applicationGuildCommands(CLIENT_ID, GUILD_ID),
      { body: commands }
    );
    console.log(`Successfully reloaded ${data.length} application (/) commands.`);
  } catch (error) {
    console.error('Error registering commands:', error);
    process.exit(1);
  }
})();
