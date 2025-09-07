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

export async function strip_out_and_execute_pre_chat_commands(userInput: string): Promise<string> {
  const lines = userInput.split('\n');
  let firstNonCommandIndex = 0;

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (trimmedLine === '-v') {
      state.verbose = true;
      getLogger().info('Verbose mode enabled.');
      firstNonCommandIndex++;
    } else if (trimmedLine === '-x') {
      state.debug = true;
      state.verbose = true; // As per instructions, -x implies -v
      getLogger().info('Debug mode enabled (verbose mode also enabled).');
      firstNonCommandIndex++;
    } else if (/^[A-Z0-9]+$/.test(trimmedLine)) {
      getLogger().info(`Ticker command detected: ${trimmedLine}.`);
      const rssdId = await getRssdIdForTicker(trimmedLine);
      if (rssdId) {
        getLogger().info(`Found RSSD ID: ${rssdId} for ticker ${trimmedLine}.`);
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

  return lines.slice(firstNonCommandIndex).join('\n');
}
