# Use the official NGINX image from Docker Hub
FROM nginx:alpine

# Remove the default nginx website
RUN rm -rf /usr/share/nginx/html/*

# Copy our static website files to the NGINX html directory
COPY app/ /usr/share/nginx/html

# Expose port 80 to allow traffic to the web server
EXPOSE 80

# The command to start NGINX when the container starts
CMD ["nginx", "-g", "daemon off;"]

