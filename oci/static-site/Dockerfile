FROM node:20-alpine as builder

WORKDIR /opt/workspace

# Frist copy only package-lock.json and package.json so we can keep
# node_modules in its own cache layer based on the package files.
RUN mkdir docusaurus
COPY ./docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install

# Copy the rest of the source code to do the product build.
COPY . .
RUN cd docusaurus && npm run build

FROM caddy:alpine
COPY --from=builder /opt/workspace/caddy/Caddyfile /etc/caddy/Caddyfile
COPY --from=builder /opt/workspace/docusaurus/build /srv

