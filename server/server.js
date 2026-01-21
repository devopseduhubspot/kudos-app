import express from 'express';
import cors from 'cors';
import { v4 as uuidv4 } from 'uuid';

const app = express();
const PORT = process.env.PORT || 3001;

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage for kudos and users
let kudosData = [];
let users = new Map();

// Helper function to get or create user
const getOrCreateUser = (name, avatar) => {
  // Check if user already exists
  for (let [id, user] of users) {
    if (user.name === name) {
      return { id, ...user };
    }
  }
  
  // Create new user
  const userId = uuidv4();
  const newUser = {
    name,
    avatar: avatar || `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=random`,
    createdAt: new Date().toISOString()
  };
  
  users.set(userId, newUser);
  return { id: userId, ...newUser };
};

// Routes

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// Get all kudos
app.get('/api/kudos', (req, res) => {
  try {
    // Sort by creation date (newest first)
    const sortedKudos = [...kudosData].sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));
    res.json({
      success: true,
      data: sortedKudos,
      total: sortedKudos.length
    });
  } catch (error) {
    console.error('Error fetching kudos:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch kudos'
    });
  }
});

// Create new kudos
app.post('/api/kudos', (req, res) => {
  try {
    const { recipientName, message, giverName, giverAvatar } = req.body;

    // Validation
    if (!recipientName || !message || !giverName) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: recipientName, message, and giverName are required'
      });
    }

    if (message.length > 500) {
      return res.status(400).json({
        success: false,
        error: 'Message must be 500 characters or less'
      });
    }

    // Get or create giver user
    const giver = getOrCreateUser(giverName, giverAvatar);

    // Create kudos entry
    const newKudos = {
      id: uuidv4(),
      recipientName: recipientName.trim(),
      message: message.trim(),
      giver: {
        id: giver.id,
        name: giver.name,
        avatar: giver.avatar
      },
      createdAt: new Date().toISOString(),
      likes: 0,
      likedBy: []
    };

    kudosData.push(newKudos);

    console.log(`New kudos created: ${giver.name} → ${recipientName}`);

    res.status(201).json({
      success: true,
      data: newKudos
    });
  } catch (error) {
    console.error('Error creating kudos:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create kudos'
    });
  }
});

// Like/unlike kudos
app.post('/api/kudos/:id/like', (req, res) => {
  try {
    const { id } = req.params;
    const { userName } = req.body;

    if (!userName) {
      return res.status(400).json({
        success: false,
        error: 'userName is required'
      });
    }

    const kudos = kudosData.find(k => k.id === id);
    if (!kudos) {
      return res.status(404).json({
        success: false,
        error: 'Kudos not found'
      });
    }

    const userIndex = kudos.likedBy.indexOf(userName);
    
    if (userIndex === -1) {
      // Add like
      kudos.likedBy.push(userName);
      kudos.likes = kudos.likedBy.length;
    } else {
      // Remove like
      kudos.likedBy.splice(userIndex, 1);
      kudos.likes = kudos.likedBy.length;
    }

    res.json({
      success: true,
      data: {
        id: kudos.id,
        likes: kudos.likes,
        likedBy: kudos.likedBy,
        userLiked: kudos.likedBy.includes(userName)
      }
    });
  } catch (error) {
    console.error('Error updating kudos like:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update kudos like'
    });
  }
});

// Get kudos statistics
app.get('/api/stats', (req, res) => {
  try {
    const totalKudos = kudosData.length;
    const totalUsers = users.size;
    const totalLikes = kudosData.reduce((sum, kudos) => sum + kudos.likes, 0);

    // Most active giver
    const giverCounts = {};
    kudosData.forEach(kudos => {
      giverCounts[kudos.giver.name] = (giverCounts[kudos.giver.name] || 0) + 1;
    });
    
    const mostActiveGiver = Object.keys(giverCounts).length > 0 
      ? Object.keys(giverCounts).reduce((a, b) => giverCounts[a] > giverCounts[b] ? a : b)
      : null;

    // Most appreciated recipient
    const recipientCounts = {};
    kudosData.forEach(kudos => {
      recipientCounts[kudos.recipientName] = (recipientCounts[kudos.recipientName] || 0) + 1;
    });
    
    const mostAppreciatedRecipient = Object.keys(recipientCounts).length > 0 
      ? Object.keys(recipientCounts).reduce((a, b) => recipientCounts[a] > recipientCounts[b] ? a : b)
      : null;

    res.json({
      success: true,
      data: {
        totalKudos,
        totalUsers,
        totalLikes,
        mostActiveGiver,
        mostAppreciatedRecipient,
        averageLikesPerKudos: totalKudos > 0 ? (totalLikes / totalKudos).toFixed(1) : 0
      }
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch statistics'
    });
  }
});

// Delete kudos (optional - for admin/cleanup)
app.delete('/api/kudos/:id', (req, res) => {
  try {
    const { id } = req.params;
    const kudosIndex = kudosData.findIndex(k => k.id === id);
    
    if (kudosIndex === -1) {
      return res.status(404).json({
        success: false,
        error: 'Kudos not found'
      });
    }

    const deletedKudos = kudosData.splice(kudosIndex, 1)[0];
    
    res.json({
      success: true,
      message: 'Kudos deleted successfully',
      data: deletedKudos
    });
  } catch (error) {
    console.error('Error deleting kudos:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete kudos'
    });
  }
});

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Kudos API server running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/health`);
  console.log(`📝 API endpoints:`);
  console.log(`   GET  /api/kudos - Get all kudos`);
  console.log(`   POST /api/kudos - Create new kudos`);
  console.log(`   POST /api/kudos/:id/like - Like/unlike kudos`);
  console.log(`   GET  /api/stats - Get statistics`);
});

export default app;