# Kudos App Backend

A simple Node.js/Express API server for the Kudos application that provides shared data persistence.

## Features

- RESTful API for kudos management
- In-memory data storage (easily replaceable with database)
- User management with avatar support
- Like/unlike functionality
- Real-time statistics
- CORS enabled for cross-origin requests

## API Endpoints

### Health Check
- `GET /health` - Server health status

### Kudos Management
- `GET /api/kudos` - Get all kudos (sorted by newest first)
- `POST /api/kudos` - Create new kudos
- `POST /api/kudos/:id/like` - Like/unlike a kudos
- `DELETE /api/kudos/:id` - Delete a kudos (admin function)

### Statistics
- `GET /api/stats` - Get application statistics

## Quick Start

1. Install dependencies:
```bash
npm install
```

2. Start the development server:
```bash
npm run dev
```

3. Start the production server:
```bash
npm start
```

The server will run on port 3001 by default (or the port specified in the PORT environment variable).

## Environment Variables

- `PORT` - Server port (default: 3001)

## Data Structure

### Kudos Object
```json
{
  "id": "uuid",
  "recipientName": "string",
  "message": "string",
  "giver": {
    "id": "uuid",
    "name": "string",
    "avatar": "string"
  },
  "createdAt": "ISO date string",
  "likes": 0,
  "likedBy": ["username1", "username2"]
}
```

### User Object
```json
{
  "id": "uuid",
  "name": "string", 
  "avatar": "string",
  "createdAt": "ISO date string"
}
```

## Future Enhancements

- Replace in-memory storage with persistent database (MongoDB, PostgreSQL, etc.)
- Add user authentication and authorization
- Implement rate limiting
- Add input sanitization and validation
- Add real-time updates with WebSockets
- Add API documentation with Swagger/OpenAPI