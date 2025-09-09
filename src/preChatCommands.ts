import { state } from './state';
import * as duckdb from 'duckdb';
import { getLogger } from './requestLogger';

const db = new duckdb.Database(':memory:');
const parquetFile = '/Users/x/dp/git/a/data/ticker_to_rssd.parquet';

async function getRssdIdForTicker(ticker: string): Promise<string | null> {
  return new Promise((resolve, reject) => {
    db.all(`SELECT rssd_id FROM '${parquetFile}' WHERE ticker = ?`, ticker, (err, res) => {
      if (err) {
        return reject(err);
      }
      if (res.length > 0) {
        // Assuming the column is named rssd_id and exists in the result
        const row = res[0] as { rssd_id: string };
        resolve(row.rssd_id);
      } else {
        resolve(null);
      }
    });
  });
}

export async function strip_out_and_execute_pre_chat_commands(userInput: string): Promise<string[]> {
  const lines = userInput.split('\n');
  let firstNonCommandIndex = 0;
  let pre_chat_commands_status_message = '';

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (trimmedLine === '-v') {
      state.verbose = true;
      pre_chat_commands_status_message += 'Verbose mode enabled.\n<br>';
      getLogger().info(pre_chat_commands_status_message);
      firstNonCommandIndex++;
    } else if (trimmedLine === '-x') {
      state.debug = true;
      state.verbose = true;
      pre_chat_commands_status_message += 'Debug mode enabled (verbose mode also enabled).<br>'
      getLogger().info(pre_chat_commands_status_message);
      firstNonCommandIndex++;
    } else if (/^[A-Z0-9]+$/.test(trimmedLine)) {
      let ticker = trimmedLine;
      getLogger().info(`Ticker detected: ${ticker}.`);
      const rssdId = await getRssdIdForTicker(ticker);
      if (rssdId) {
        getLogger().info(`Found RSSD ID: ${rssdId} for ticker ${ticker}.`);
        pre_chat_commands_status_message += `OK: from ticker ${ticker}: resolved to RSSD ID: ${rssdId}.<br>`;
        // Here you would gather metrics related to the firm
      } else {
        getLogger().info(`No RSSD ID found for ticker ${trimmedLine}.`);
      }
      firstNonCommandIndex++;
    } else {
      // First line that is not a command
      break;
    }
  }
  userInput = lines.slice(firstNonCommandIndex).join('\n').trim()
  return [userInput, pre_chat_commands_status_message];
}
