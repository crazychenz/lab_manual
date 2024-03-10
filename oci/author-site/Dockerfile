FROM node:20-alpine

WORKDIR /opt/workspace

# Frist copy only package-lock.json and package.json so we can keep
# node_modules in its own cache layer based on the package files.
RUN mkdir docusaurus
COPY ./docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install

# Copy the rest of the source code to do the product build.
COPY . .
WORKDIR /opt/workspace/docusaurus

CMD ["npm", "run", "start"] 
#, "--", "-h 0.0.0.0"]