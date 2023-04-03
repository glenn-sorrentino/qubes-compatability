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

# Create app.py file
cat > app.py << EOL
from flask import Flask, render_template_string
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)

url = 'https://www.qubes-os.org/hcl/'
html_content = requests.get(url).content
soup = BeautifulSoup(html_content, 'html.parser')

table = soup.find('table', class_='table table-hover table-bordered table-responsive sortable more-bottom')

rows = table.find_all('tr')

filtered_rows = []

for row in rows:
    row_data = row.find_all('td', class_='success text-center')
    if len(row_data) >= 7:  # Adjusted to 7 instead of 8, to exclude BIOS column
        filtered_rows.append(row)

header = rows[0]
header.name = 'thead'

new_table = soup.new_tag('table', **{'class': 'table table-hover table-bordered table-responsive'})
new_table.append(header)

for filtered_row in filtered_rows:
    new_table.append(filtered_row)

@app.route('/')
def index():
    return render_template_string('''<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <title>Qubes HCL</title>
</head>
<body>
<div class="container">
    <h1>Qubes Hardware Compatibility List</h1>
    <p>Showing only laptops with "yes" marked in HVM, IOMMU, SLAT, TPM, Qubes, Xen, and Kernel columns.</p>
    {{ new_table | safe }}
</div>
</body>
</html>''', new_table=str(new_table))

if __name__ == '__main__':
    app.run(debug=True)
EOL

# Create wsgi.py file
cat > wsgi.py << EOL
from app import app

if __name__ == "__main__":
    app.run()
EOL

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
gunicorn --bind 127.0.0.1:8000 wsgi:app
