import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { UserProvider } from './context/UserContext';
import LoginModal from './components/LoginModal';
import Dashboard from './pages/Dashboard';
import NewKudos from './pages/NewKudos';
import Confirmation from './pages/Confirmation';

function App() {
  return (
    <UserProvider>
      <BrowserRouter>
        <div className="min-h-screen bg-gradient-to-br from-purple-50 to-blue-50">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/new" element={<NewKudos />} />
            <Route path="/confirmation" element={<Confirmation />} />
          </Routes>
          <LoginModal />
        </div>
      </BrowserRouter>
    </UserProvider>
  );
}

export default App;
