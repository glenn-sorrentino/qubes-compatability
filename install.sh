#!/bin/bash

# Update packages
sudo apt-get update

# Install Python 3 and pip
sudo apt-get install -y python3 python3-pip

# Install virtualenv
pip3 install virtualenv

# Create and activate the virtual environment
virtualenv venv
source venv/bin/activate

# Install Flask, Beautiful Soup, and Requests
pip install Flask beautifulsoup4 requests gunicorn

# Install Nginx
sudo apt-get install -y nginx

# Create Nginx configuration
sudo bash -c 'cat > /etc/nginx/sites-available/qubes_hcl << EOL
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOL'

# Create a symlink for the Nginx configuration
sudo ln -s /etc/nginx/sites-available/qubes_hcl /etc/nginx/sites-enabled/qubes_hcl

# Remove the default Nginx configuration
sudo rm /etc/nginx/sites-enabled/default

# Restart Nginx
sudo systemctl restart nginx

# Run the app with Gunicorn
gunicorn --bind 127.0.0.1:8000 app:app
