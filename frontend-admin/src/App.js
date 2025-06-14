import React from 'react';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import Desktop1 from './components/Desktop1/Desktop1';
import Desktop2 from './components/Desktop2/Desktop2';

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/desktop1" element={<Desktop1 />} />
        <Route path="/desktop2" element={<Desktop2 />} />
        <Route path="/" element={<Desktop2 />} /> {/* Default route */}
      </Routes>
    </Router>
  );
}

export default App;
