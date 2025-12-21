import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';

function NewKudos() {
  const navigate = useNavigate();
  const [recipientName, setRecipientName] = useState('');
  const [message, setMessage] = useState('');
  const [errors, setErrors] = useState({});
  const validateForm = () => {
    const newErrors = {};
    if (!recipientName.trim()) newErrors.recipientName = 'Please enter a recipient name.';
    if (message.trim().length < 10) newErrors.message = 'Message must be at least 10 characters long.';
    return newErrors;
  };
  const handleSubmit = (event) => {
    event.preventDefault();

    const newErrors = validateForm();
    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    setErrors({});

    const savedKudos = localStorage.getItem('kudosList');
    const kudosArray = savedKudos ? JSON.parse(savedKudos) : [];

    kudosArray.push({
      name: recipientName.trim(),
      message: message.trim()
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
                className={`w-full px-5 py-4 border-2 rounded-xl focus:outline-none focus:ring-4 focus:border-indigo-500 text-lg ${
                  errors.recipientName ? 'border-red-500 focus:ring-red-300' : 'border-gray-300 focus:ring-indigo-300'
                }`}
                placeholder="Who deserves recognition?"
              />
              {errors.recipientName && (
                <p className="text-red-500 text-sm font-semibold mt-2">{errors.recipientName}</p>
              )}
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
                className={`w-full px-5 py-4 border-2 rounded-xl focus:outline-none focus:ring-4 focus:border-indigo-500 resize-none text-lg ${
                  errors.message ? 'border-red-500 focus:ring-red-300' : 'border-gray-300 focus:ring-indigo-300'
                }`}
                placeholder="Express your appreciation..."
              />
              <div className="flex justify-between items-center mt-2">
                <div>
                  {errors.message && (
                    <p className="text-red-500 text-sm font-semibold">{errors.message}</p>
                  )}
                </div>
                <p className={`text-sm ${message.length < 10 ? 'text-red-500 font-semibold' : 'text-gray-500'}`}>
                  {message.length}/10
                </p>
              </div>
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
