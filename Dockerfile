FROM node:18-alpine AS build
WORKDIR /app

# Install dependencies
COPY package.json package-lock.json* ./
RUN npm ci --silent

# Copy source and build with environment variable
COPY . .
# Set empty API URL so /api/kudos works directly with nginx proxy
ENV VITE_API_URL=""
RUN npm run build

FROM nginx:stable-alpine
# Copy built application
COPY --from=build /app/dist /usr/share/nginx/html
# Copy nginx configuration
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

