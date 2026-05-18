const express = require('express');
const app = express();
const port = 3000;

// Regular application route
app.get('/', (req, res) => {
  res.send('Hello from the Hardened Jenkins-Docker Pipeline! 🚀');
});

// Crucial health check endpoint for our Jenkins Pipeline Smoke Test
app.get('/health', (req, res) => {
  res.status(200).json({ status: 'UP', timestamp: new Date() });
});

app.listen(port, () => {
  console.log(`Application running securely on port ${port}`);
});

