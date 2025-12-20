import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

function NewKudos() {
  const navigate = useNavigate();
  const [recipientName, setRecipientName] = useState('');
  const [message, setMessage] = useState('');

  const handleSubmit = (event) => {
    event.preventDefault();

    const savedKudos = localStorage.getItem('kudosList');
    const kudosArray = savedKudos ? JSON.parse(savedKudos) : [];

    kudosArray.push({
      name: recipientName,
      message: message
    });

    localStorage.setItem('kudosList', JSON.stringify(kudosArray));
    navigate('/confirmation');
  };

  return (
    <div className="container mx-auto px-6 py-10">
      <div className="max-w-3xl mx-auto">
        <Link
          to="/"
          className="text-indigo-600 hover:text-indigo-800 mb-8 inline-flex items-center font-semibold text-lg"
        >
          <svg className="w-6 h-6 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 19l-7-7 7-7" />
          </svg>
          Back to Dashboard
        </Link>

        <div className="bg-white rounded-3xl shadow-2xl p-10 mt-6">
          <h1 className="text-4xl font-extrabold text-indigo-900 mb-8">Give Kudos</h1>

          <form onSubmit={handleSubmit} className="space-y-8">
            <div>
              <label
                htmlFor="recipientName"
                className="block text-gray-800 font-bold mb-3 text-lg"
              >
                Recipient Name
              </label>
              <input
                type="text"
                id="recipientName"
                value={recipientName}
                onChange={(e) => setRecipientName(e.target.value)}
                className="w-full px-5 py-4 border-2 border-gray-300 rounded-xl focus:outline-none focus:ring-4 focus:ring-indigo-300 focus:border-indigo-500 text-lg"
                placeholder="Who deserves recognition?"
              />
            </div>

            <div>
              <label
                htmlFor="message"
                className="block text-gray-800 font-bold mb-3 text-lg"
              >
                Message
              </label>
              <textarea
                id="message"
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                rows="7"
                className="w-full px-5 py-4 border-2 border-gray-300 rounded-xl focus:outline-none focus:ring-4 focus:ring-indigo-300 focus:border-indigo-500 resize-none text-lg"
                placeholder="Express your appreciation..."
              />
            </div>

            <button
              type="submit"
              className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-bold py-4 px-8 rounded-xl shadow-lg transform hover:scale-105 transition-all text-lg"
            >
              Send Kudos
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

export default NewKudos;
