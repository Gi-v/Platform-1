FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install --production --silent
COPY . .
EXPOSE 3030
ENV PORT=3030
USER node
CMD ["node", "server.js"]
