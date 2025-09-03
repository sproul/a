import express from 'express';
import path from 'path';

const app = express();
const port = 3000;

// Middleware to parse URL-encoded bodies (as sent by HTML forms)
app.use(express.urlencoded({ extended: true }));

// Serve static files from the 'public' directory
app.use(express.static(path.join(__dirname, '../public')));

app.post('/chat', (req, res) => {
    const userInput = req.body.chat_input;
    const response = `${userInput} SEEN`;
    // Send back an HTML fragment
    res.send(`<div><strong>You:</strong> ${userInput}</div><div><strong>Bot:</strong> ${response}</div>`);
});

app.listen(port, () => {
  console.log(`Server is running at http://localhost:${port}`);
});
