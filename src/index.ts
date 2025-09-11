import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
import fs from 'fs';
import { ChatOpenAI } from '@langchain/openai';
import logger from './logger';
import { getLogger, runWithRequestLogger } from './requestLogger';
import { strip_out_and_execute_pre_chat_commands } from './preChatCommands';
import { state } from './state';
import { StreamTransport } from './streamTransport';
import winston, {log} from 'winston';

// Load environment variables from .env file
dotenv.config();

const app = express();
const port = 3000;

// Initialize the OpenAI model
const model = new ChatOpenAI({
    modelName: process.env.MODEL || 'gpt-5',
});

// Middleware to log every request
app.use((req, _res, next) => {
    logger.info(`Request: ${req.method} ${req.originalUrl}`);
    next();
});

// Middleware to parse URL-encoded bodies (as sent by HTML forms)
app.use(express.urlencoded({ extended: true }));

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, '../public')));

// Function to read and parse ticker/rssd_id pairs from CSV
function getTickerRssdPairs(): Array<{ticker: string, rssd_id: string}> {
    const csvPath = path.join(__dirname, '../public/updated_ticker_rssd_id_pairs.csv');
    
    try {
        if (!fs.existsSync(csvPath)) {
            return [];
        }
        
        const csvContent = fs.readFileSync(csvPath, 'utf-8').trim();
        if (!csvContent) {
            return [];
        }
        
        const lines = csvContent.split('\n').filter(line => line.trim());
        const pairs: Array<{ticker: string, rssd_id: string}> = [];
        
        for (const line of lines) {
            const [ticker, rssd_id] = line.split(',').map(s => s.trim());
            if (ticker && rssd_id) {
                pairs.push({ ticker, rssd_id });
            }
        }
        
        return pairs;
    } catch (error) {
        logger.error('Error reading ticker/rssd_id pairs:', error);
        return [];
    }
}

// API endpoint to get ticker/rssd_id pairs
app.get('/api/ticker-pairs', (req, res) => {
    const pairs = getTickerRssdPairs();
    res.json(pairs);
});

// Function to extract content from HTML report files
function extractReportContent(rssd_id: string): {html: string, text: string} | null {
    const reportPath = path.join(__dirname, `../public/firms_by_rssd_id/${rssd_id}/report.htm`);
    
    try {
        if (!fs.existsSync(reportPath)) {
            return null;
        }
        
        const htmlContent = fs.readFileSync(reportPath, 'utf-8');
        
        // Extract content from body tag
        const bodyMatch = htmlContent.match(/<body[^>]*>([\s\S]*?)<\/body>/i);
        if (!bodyMatch) {
            return null;
        }
        
        let htmlBody = bodyMatch[1].trim();
        
        // Convert HTML to readable text for LLM context (keep existing logic)
        let textContent = htmlBody
            .replace(/<h1[^>]*>/gi, '\n# ')
            .replace(/<h2[^>]*>/gi, '\n## ')
            .replace(/<h3[^>]*>/gi, '\n### ')
            .replace(/<\/h[1-6]>/gi, '\n')
            .replace(/<p[^>]*>/gi, '\n')
            .replace(/<\/p>/gi, '\n')
            .replace(/<li[^>]*>/gi, '\n• ')
            .replace(/<\/li>/gi, '')
            .replace(/<ul[^>]*>|<\/ul>/gi, '')
            .replace(/<div[^>]*>|<\/div>/gi, '\n')
            .replace(/<[^>]*>/g, '') // Remove remaining HTML tags
            .replace(/\n\s*\n/g, '\n') // Remove extra blank lines
            .trim();
        
        return { html: htmlBody, text: textContent };
    } catch (error) {
        logger.error('Error reading report file:', error);
        return null;
    }
}

// API endpoint to get report content
app.get('/api/report/:rssd_id', (req, res) => {
    const rssd_id = req.params.rssd_id;
    const content = extractReportContent(rssd_id);
    
    if (!content) {
        return res.status(404).json({ error: 'Report not found' });
    }
    
    res.json({ html: content.html, text: content.text, rssd_id });
});

function finish(res: express.Response, userInput: string, logMessage: string, error?: any, userMessage?: string) {
    const logger = getLogger();
    let message: string | null
    let message_type: string | null
    if (error !== null && error !== undefined) {
        logger.error(logMessage, error);
        message = error instanceof Error ? error.message : (userMessage || 'An error occurred pre-chat, and the command was not executed.');
        message_type = "Error"
    } else {
        message_type = "Info"
        logger.info(logMessage);
        message = logMessage
    }
    if (!res.headersSent) {
        res.write(`<div><strong>You:</strong> ${userInput}</div>`);
    }
    if (!res.writableEnded) {
        res.write(`<div><strong>${message_type}</strong> ${message}</div>`);
        res.end();
    }
}

// Store chat history for context
let chatHistory: Array<{role: 'user' | 'system' | 'assistant', content: string}> = [];

app.post('/chat', async (req, res) => {
    const userInput = req.body.chat_input;
    const requestLogger = winston.createLogger({
        transports: [
            new winston.transports.Console(),
            // You can add other transports here, like file transports
        ],
    });

    await runWithRequestLogger(requestLogger, async () => {
        const logger = getLogger();
        logger.info(`Request Body: ${JSON.stringify(req.body)}`);
        let llmInput: string;
        let pre_chat_commands_status_message: string;
        try {
            [llmInput, pre_chat_commands_status_message] = await strip_out_and_execute_pre_chat_commands(userInput);
        } catch (error) {
            finish(res, userInput, 'Error executing pre-chat command:', error);
            return;
        }

        if (state.debug) {
            res.setHeader('Content-Type', 'text/html; charset=utf-8');
            res.setHeader('Transfer-Encoding', 'chunked');
            requestLogger.add(new StreamTransport({res}));
        }

        if (!llmInput) {
            if (!pre_chat_commands_status_message.trim()) {
                finish(res, llmInput, 'No user input and no local commands.', null, 'Please provide some input.');
                return;
            }
        }

        try {
            if (!res.headersSent) {
                res.write(`<div><strong>You:</strong> ${userInput}</div>`);
            }
            if (!res.writableEnded) {
                res.write(`<div><strong>Appleby:</strong> ${pre_chat_commands_status_message}</div>`);
            }
            if (llmInput) {
                // Add user input to chat history
                chatHistory.push({role: 'user', content: llmInput});
                
                // Build context from chat history
                const messages = chatHistory.map(msg => ({
                    role: msg.role,
                    content: msg.content
                }));
                
                const response = await model.invoke(messages);
                const botResponse = response.content.toString();
                
                // Add bot response to chat history
                chatHistory.push({role: 'assistant', content: botResponse});
                
                // Keep chat history manageable (last 20 messages)
                if (chatHistory.length > 20) {
                    chatHistory = chatHistory.slice(-20);
                }
                
                if (!res.writableEnded) {
                    res.write(`<div><strong>Bot:</strong> ${botResponse}</div>`);
                }
            }
            res.end();
        } catch (error) {
            finish(res, userInput, 'Error calling OpenAI:', error, 'Could not get a response from the AI model.');
        }
    });
});

// API endpoint to add report content to chat history
app.post('/api/report-context', express.json(), (req, res) => {
    const { ticker, rssd_id, content } = req.body;
    
    if (!ticker || !rssd_id || !content) {
        return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Add report context to chat history (use text version for LLM)
    const contextMessage = `User requested to view the ${ticker} (RSSD ID: ${rssd_id}) financial report. Here is the report content:\n\n${content}`;
    chatHistory.push({role: 'system', content: contextMessage});
    
    // Keep chat history manageable
    if (chatHistory.length > 20) {
        chatHistory = chatHistory.slice(-20);
    }
    
    res.json({ success: true });
});

app.listen(port, () => {
  logger.info(`Server is running at http://localhost:${port}`);
});
