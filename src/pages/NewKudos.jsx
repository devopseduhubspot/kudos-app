import React, { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useUser } from '../context/UserContext';
import kudosAPI from '../api/kudosAPI';

function NewKudos() {
  const navigate = useNavigate();
  const { user, openLoginModal } = useUser();
  const [recipientName, setRecipientName] = useState('');
  const [message, setMessage] = useState('');
  const [errors, setErrors] = useState({});
  const [loading, setLoading] = useState(false);

  const validateForm = () => {
    const newErrors = {};
    if (!recipientName.trim()) newErrors.recipientName = 'Please enter a recipient name.';
    if (message.trim().length < 10) newErrors.message = 'Message must be at least 10 characters long.';
    if (message.trim().length > 500) newErrors.message = 'Message must be 500 characters or less.';
    return newErrors;
  };

  const handleSubmit = async (event) => {
    event.preventDefault();

    // Check if user is logged in
    if (!user) {
      openLoginModal();
      return;
    }

    const newErrors = validateForm();
    if (Object.keys(newErrors).length > 0) {
      setErrors(newErrors);
      return;
    }

    setErrors({});
    setLoading(true);

    try {
      const kudosData = {
        recipientName: recipientName.trim(),
        message: message.trim(),
        giverName: user.name,
        giverAvatar: user.avatar
      };

      await kudosAPI.createKudos(kudosData);
      
      // Also save to localStorage as backup
      const savedKudos = localStorage.getItem('kudosList');
      const kudosArray = savedKudos ? JSON.parse(savedKudos) : [];
      kudosArray.push({
        name: recipientName.trim(),
        message: message.trim()
      });
      localStorage.setItem('kudosList', JSON.stringify(kudosArray));

      navigate('/confirmation');
    } catch (error) {
      console.error('Failed to create kudos:', error);
      setErrors({ submit: 'Failed to send kudos. Please try again.' });
    } finally {
      setLoading(false);
    }
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

          {!user && (
            <div className="bg-yellow-50 border border-yellow-200 rounded-lg p-4 mb-6">
              <p className="text-yellow-800 text-sm">
                You need to sign in to send kudos.{' '}
                <button
                  onClick={openLoginModal}
                  className="text-indigo-600 hover:text-indigo-800 font-semibold"
                >
                  Sign in here
                </button>
              </p>
            </div>
          )}

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
                disabled={loading}
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
                disabled={loading}
              />
              <div className="flex justify-between items-center mt-2">
                <div>
                  {errors.message && (
                    <p className="text-red-500 text-sm font-semibold">{errors.message}</p>
                  )}
                  {errors.submit && (
                    <p className="text-red-500 text-sm font-semibold">{errors.submit}</p>
                  )}
                </div>
                <p className={`text-sm ${message.length < 10 ? 'text-red-500 font-semibold' : message.length > 450 ? 'text-orange-500 font-semibold' : 'text-gray-500'}`}>
                  {message.length}/500
                </p>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading || !user}
              className={`w-full font-bold py-4 px-8 rounded-xl shadow-lg transform transition-all text-lg ${
                loading || !user
                  ? 'bg-gray-400 cursor-not-allowed'
                  : 'bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white hover:scale-105'
              }`}
            >
              {loading ? (
                <div className="flex items-center justify-center">
                  <div className="animate-spin rounded-full h-5 w-5 border-b-2 border-white mr-2"></div>
                  Sending Kudos...
                </div>
              ) : (
                'Send Kudos'
              )}
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}

export default NewKudos;
