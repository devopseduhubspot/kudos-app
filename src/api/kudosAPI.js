// API configuration
const API_BASE_URL = import.meta.env.VITE_API_URL !== undefined ? import.meta.env.VITE_API_URL : 'http://localhost:3001';

class KudosAPI {
  constructor() {
    this.baseURL = API_BASE_URL;
  }

  // Helper method for making API requests
  async request(endpoint, options = {}) {
    const url = `${this.baseURL}${endpoint}`;
    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    try {
      const response = await fetch(url, config);
      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || `HTTP error! status: ${response.status}`);
      }

      return data;
    } catch (error) {
      console.error(`API request failed: ${endpoint}`, error);
      throw error;
    }
  }

  // Get all kudos
  async getKudos() {
    return this.request('/api/kudos');
  }

  // Create new kudos
  async createKudos(kudosData) {
    return this.request('/api/kudos', {
      method: 'POST',
      body: JSON.stringify(kudosData),
    });
  }

  // Like/unlike kudos
  async likeKudos(kudosId, userName) {
    return this.request(`/api/kudos/${kudosId}/like`, {
      method: 'POST',
      body: JSON.stringify({ userName }),
    });
  }

  // Get statistics
  async getStats() {
    return this.request('/api/stats');
  }

  // Delete kudos (admin function)
  async deleteKudos(kudosId) {
    return this.request(`/api/kudos/${kudosId}`, {
      method: 'DELETE',
    });
  }

  // Health check
  async healthCheck() {
    return this.request('/health');
  }
}

// Create and export a singleton instance
const kudosAPI = new KudosAPI();
export default kudosAPI;

// Export individual methods for convenience
export const {
  getKudos,
  createKudos,
  likeKudos,
  getStats,
  deleteKudos,
  healthCheck
} = kudosAPI;