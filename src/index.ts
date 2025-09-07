import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
import { ChatOpenAI } from '@langchain/openai';
import logger from './logger';
import { getLogger, runWithRequestLogger } from './requestLogger';
import { strip_out_and_execute_pre_chat_commands } from './preChatCommands';
import { state } from './state';
import { StreamTransport } from './streamTransport';
import winston from 'winston';

// Load environment variables from .env file
dotenv.config();

const app = express();
const port = 3000;

// Initialize the OpenAI model
const model = new ChatOpenAI({
    modelName: process.env.MODEL || 'gpt-5',
});

// Middleware to log every request
app.use((req, res, next) => {
    logger.info(`Request: ${req.method} ${req.originalUrl}`);
    next();
});

// Middleware to parse URL-encoded bodies (as sent by HTML forms)
app.use(express.urlencoded({ extended: true }));

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, '../public')));

function fail(res: express.Response, userInput: string, logMessage: string, error?: any, userMessage?: string) {
    const logger = getLogger();
    if (error !== null && error !== undefined) {
        logger.error(logMessage, error);
    } else {
        logger.error(logMessage);
    }
    const errorMessage = error instanceof Error ? error.message : (userMessage || 'An error occurred pre-chat, and the command was not executed.');
    if (!res.headersSent) {
        res.write(`<div><strong>You:</strong> ${userInput}</div>`);
    }
    if (!res.writableEnded) {
        res.write(`<div><strong>Error:</strong> ${errorMessage}</div>`);
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

    runWithRequestLogger(requestLogger, async () => {
        const logger = getLogger();
        logger.info(`Request Body: ${JSON.stringify(req.body)}`);
        let processedUserInput;

        try {
            processedUserInput = await strip_out_and_execute_pre_chat_commands(userInput);
        } catch (error) {
            fail(res, userInput, 'Error executing pre-chat command:', error);
            return;
        }

        if (state.debug) {
            res.setHeader('Content-Type', 'text/html; charset=utf-8');
            res.setHeader('Transfer-Encoding', 'chunked');
            requestLogger.add(new StreamTransport({ res }));
        }

        if (!processedUserInput.trim()) {
            fail(res, userInput, 'User input is empty after processing commands.', null, 'Please provide some input.');
            return;
        }

        try {
            if (!res.headersSent) {
                res.write(`<div><strong>You:</strong> ${userInput}</div>`);
            }
            const response = await model.invoke(processedUserInput);
            const botResponse = response.content.toString();
            
            if (!res.writableEnded) {
                res.write(`<div><strong>Bot:</strong> ${botResponse}</div>`);
                res.end();
            }
        } catch (error) {
            fail(res, userInput, 'Error calling OpenAI:', error, 'Could not get a response from the AI model.');
        }
    });
});

app.listen(port, () => {
  logger.info(`Server is running at http://localhost:${port}`);
});
