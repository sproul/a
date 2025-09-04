import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
import { ChatOpenAI } from '@langchain/openai';
import logger from './logger';

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

app.post('/chat', async (req, res) => {
    const userInput = req.body.chat_input;
    logger.info(`Request Body: ${JSON.stringify(req.body)}`);

    try {
        const response = await model.invoke(userInput);
        const botResponse = response.content.toString();
        
        const responseHtml = `<div><strong>You:</strong> ${userInput}</div><div><strong>Bot:</strong> ${botResponse}</div>`;
        logger.info(`Response: ${responseHtml}`);
        res.send(responseHtml);
    } catch (error) {
        logger.error('Error calling OpenAI:', error);
        const errorHtml = `<div><strong>You:</strong> ${userInput}</div><div><strong>Error:</strong> Could not get a response. Please check the server logs and ensure your OPENAI_API_KEY is correct.</div>`;
        logger.info(`Response (Error): ${errorHtml}`);
        res.send(errorHtml);
    }
});

app.listen(port, () => {
  logger.info(`Server is running at http://localhost:${port}`);
});
