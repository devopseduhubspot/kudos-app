import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';

function Dashboard() {
  const [kudosList, setKudosList] = useState([]);

  useEffect(() => {
    const savedKudos = localStorage.getItem('kudosList');
    if (savedKudos) {
      setKudosList(JSON.parse(savedKudos));
    }
  }, []);

  return (
    <div className="container mx-auto px-6 py-10">
      <header className="mb-10 flex justify-between items-center">
        <h1 className="text-5xl font-extrabold text-indigo-900">Kudos Board</h1>
        <Link
          to="/new"
          className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 px-8 rounded-full shadow-lg transform hover:scale-105 transition-all"
        >
          + New Kudos
        </Link>
      </header>

      {kudosList.length === 0 ? (
        <div className="text-center py-24">
          <p className="text-gray-400 text-2xl">No kudos yet. Start spreading appreciation!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {kudosList.map((kudos, index) => (
            <article
              key={index}
              className="bg-white rounded-2xl shadow-xl p-8 border-l-4 border-indigo-500 hover:shadow-2xl transition-shadow"
            >
              <div className="flex items-center gap-4 mb-5">
                <div className="w-14 h-14 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full flex items-center justify-center text-white font-bold text-2xl shadow-md">
                  {kudos.name.charAt(0).toUpperCase()}
                </div>
                <h3 className="text-2xl font-bold text-gray-800">
                  {kudos.name}
                </h3>
              </div>
              <p className="text-gray-700 text-lg leading-relaxed italic">
                "{kudos.message}"
              </p>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

export default Dashboard;
