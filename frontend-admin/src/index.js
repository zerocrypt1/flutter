import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css'; // Global styles (if any)
import App from './App'; // Import the main App component

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
