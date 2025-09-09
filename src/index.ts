import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
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
                res.end();
            }
            if (llmInput) {
                const response = await model.invoke(llmInput);
                const botResponse = response.content.toString();

                if (!res.writableEnded) {
                    res.write(`<div><strong>Bot:</strong> ${botResponse}</div>`);
                }
                res.end();
            }
        } catch (error) {
            finish(res, userInput, 'Error calling OpenAI:', error, 'Could not get a response from the AI model.');
        }
    });
});

app.listen(port, () => {
  logger.info(`Server is running at http://localhost:${port}`);
});
