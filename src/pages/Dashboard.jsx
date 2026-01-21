import React, { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { useUser } from '../context/UserContext';
import kudosAPI from '../api/kudosAPI';

function Dashboard() {
  const [kudosList, setKudosList] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const { user, openLoginModal, logout } = useUser();

  useEffect(() => {
    loadKudos();
  }, []);

  const loadKudos = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await kudosAPI.getKudos();
      setKudosList(response.data);
    } catch (err) {
      console.error('Failed to load kudos:', err);
      setError('Failed to load kudos. Please try again.');
      // Fallback to localStorage if API fails
      const savedKudos = localStorage.getItem('kudosList');
      if (savedKudos) {
        setKudosList(JSON.parse(savedKudos));
      }
    } finally {
      setLoading(false);
    }
  };

  const handleLike = async (kudosId) => {
    if (!user) {
      openLoginModal();
      return;
    }

    try {
      const response = await kudosAPI.likeKudos(kudosId, user.name);
      // Update the local state
      setKudosList(prevKudos => 
        prevKudos.map(kudos => 
          kudos.id === kudosId 
            ? { ...kudos, likes: response.data.likes, likedBy: response.data.likedBy }
            : kudos
        )
      );
    } catch (err) {
      console.error('Failed to like kudos:', err);
      // Optionally show a toast notification here
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  return (
    <div className="container mx-auto px-6 py-10">
      <header className="mb-10 flex justify-between items-center">
        <h1 className="text-5xl font-extrabold text-indigo-900">Kudos Board</h1>
        <div className="flex items-center gap-4">
          {user ? (
            <div className="flex items-center gap-4">
              <div className="flex items-center gap-2">
                <img
                  src={user.avatar}
                  alt={user.name}
                  className="w-10 h-10 rounded-full"
                />
                <span className="text-gray-700 font-medium">{user.name}</span>
              </div>
              <button
                onClick={logout}
                className="text-gray-500 hover:text-gray-700 text-sm"
              >
                Logout
              </button>
              <Link
                to="/new"
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 px-8 rounded-full shadow-lg transform hover:scale-105 transition-all"
              >
                + New Kudos
              </Link>
            </div>
          ) : (
            <div className="flex items-center gap-4">
              <button
                onClick={openLoginModal}
                className="bg-gray-600 hover:bg-gray-700 text-white font-bold py-3 px-6 rounded-full shadow-lg transition-all"
              >
                Sign In
              </button>
              <Link
                to="/new"
                className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-3 px-8 rounded-full shadow-lg transform hover:scale-105 transition-all"
              >
                + New Kudos
              </Link>
            </div>
          )}
        </div>
      </header>

      {loading ? (
        <div className="text-center py-24">
          <div className="inline-block animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
          <p className="text-gray-600 text-lg mt-4">Loading kudos...</p>
        </div>
      ) : error ? (
        <div className="text-center py-24">
          <p className="text-red-500 text-xl mb-4">{error}</p>
          <button
            onClick={loadKudos}
            className="bg-indigo-600 hover:bg-indigo-700 text-white font-bold py-2 px-6 rounded-lg"
          >
            Try Again
          </button>
        </div>
      ) : kudosList.length === 0 ? (
        <div className="text-center py-24">
          <p className="text-gray-400 text-2xl">No kudos yet. Start spreading appreciation!</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
          {kudosList.map((kudos) => (
            <article
              key={kudos.id}
              className="bg-white rounded-2xl shadow-xl p-8 border-l-4 border-indigo-500 hover:shadow-2xl transition-shadow"
            >
              <div className="flex items-center gap-4 mb-5">
                <div className="w-14 h-14 bg-gradient-to-br from-indigo-400 to-purple-500 rounded-full flex items-center justify-center text-white font-bold text-2xl shadow-md">
                  {kudos.recipientName.charAt(0).toUpperCase()}
                </div>
                <div className="flex-1">
                  <h3 className="text-2xl font-bold text-gray-800">
                    {kudos.recipientName}
                  </h3>
                  <div className="flex items-center gap-2 mt-1">
                    <img
                      src={kudos.giver.avatar}
                      alt={kudos.giver.name}
                      className="w-6 h-6 rounded-full"
                    />
                    <span className="text-sm text-gray-500">from {kudos.giver.name}</span>
                  </div>
                </div>
              </div>
              
              <p className="text-gray-700 text-lg leading-relaxed italic mb-4">
                &quot;{kudos.message}&quot;
              </p>
              
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleLike(kudos.id)}
                    className={`flex items-center gap-1 px-3 py-1 rounded-full text-sm font-medium transition-colors ${
                      user && kudos.likedBy.includes(user.name)
                        ? 'bg-red-100 text-red-600 hover:bg-red-200'
                        : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                    }`}
                  >
                    <svg className="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M3.172 5.172a4 4 0 015.656 0L10 6.343l1.172-1.171a4 4 0 115.656 5.656L10 17.657l-6.828-6.829a4 4 0 010-5.656z" clipRule="evenodd" />
                    </svg>
                    {kudos.likes}
                  </button>
                </div>
                <span className="text-xs text-gray-400">
                  {formatDate(kudos.createdAt)}
                </span>
              </div>
            </article>
          ))}
        </div>
      )}
    </div>
  );
}

export default Dashboard;
