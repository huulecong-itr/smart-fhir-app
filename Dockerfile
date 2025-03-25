FROM node:22

WORKDIR /app

COPY package.json package-lock.json ./

RUN npm install
COPY . .
RUN npm run build
RUN npm install -g http-server
EXPOSE 3000


CMD ["http-server", "dist", "-p", "3000"]
