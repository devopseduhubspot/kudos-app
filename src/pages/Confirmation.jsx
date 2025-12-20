import React from 'react';
import { useNavigate } from 'react-router-dom';

function Confirmation() {
  const navigate = useNavigate();

  return (
    <div className="container mx-auto px-6 py-10">
      <div className="max-w-lg mx-auto mt-20">
        <div className="bg-white rounded-3xl shadow-2xl p-12 text-center">
          <div className="w-24 h-24 bg-gradient-to-br from-green-400 to-emerald-500 rounded-full flex items-center justify-center mx-auto mb-8 shadow-xl">
            <svg
              className="w-14 h-14 text-white"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={4}
                d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
              />
            </svg>
          </div>

          <h1 className="text-4xl font-extrabold text-gray-900 mb-5">Success!</h1>
          <p className="text-gray-600 mb-10 text-xl">
            Your kudos has been sent successfully.
          </p>

          <div className="space-y-4">
            <button
              onClick={() => navigate('/')}
              className="w-full bg-gradient-to-r from-indigo-600 to-purple-600 hover:from-indigo-700 hover:to-purple-700 text-white font-bold py-4 px-8 rounded-xl shadow-lg transform hover:scale-105 transition-all"
            >
              Back to Dashboard
            </button>
            <button
              onClick={() => navigate('/new')}
              className="w-full bg-gray-100 hover:bg-gray-200 text-gray-800 font-bold py-4 px-8 rounded-xl transition-all"
            >
              Send Another Kudos
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}

export default Confirmation;
