#!/bin/bash

# Update package lists and install required packages
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv nginx

# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install required Python libraries
pip install beautifulsoup4 requests gunicorn Flask

# Create the Flask application file
cat > app.py << EOL
from flask import Flask, render_template_string
import requests
from bs4 import BeautifulSoup

app = Flask(__name__)

@app.route('/')
def qubes_hcl_scraper():
    url = 'https://www.qubes-os.org/hcl/'
    response = requests.get(url)
    response.raise_for_status()
    soup = BeautifulSoup(response.text, 'html.parser')
    table = soup.find('table', {'class': 'compatibility'})
    headers = [header.text.strip() for header in table.findAll('th')]
    rows = table.findAll('tr')[1:]
    compatible_laptops = []

    for row in rows:
        cells = row.findAll('td')
        laptop_data = {headers[i]: cell.text.strip() for i, cell in enumerate(cells)}
        if all(value.lower() == 'yes' for value in laptop_data.values()):
            compatible_laptops.append(laptop_data)

    # Render the results as an HTML table
    table_headers = ''.join(f'<th>{header}</th>' for header in headers)
    table_rows = ''.join(f'<tr>{" ".join(f"<td>{row_data[key]}</td>" for key in headers)}</tr>' for row_data in compatible_laptops)
    html = f'<table><thead><tr>{table_headers}</tr></thead><tbody>{table_rows}</tbody></table>'
    return render_template_string(html)

if __name__ == '__main__':
    app.run()
EOL

# Create a systemd service file
sudo bash -c 'cat > /etc/systemd/system/qubes_hcl_scraper.service << EOL
[Unit]
Description=Qubes HCL Scraper
After=network.target

[Service]
User=$(whoami)
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin"
ExecStart=$(pwd)/venv/bin/gunicorn app:app -b 0.0.0.0:8000
Restart=always

[Install]
WantedBy=multi-user.target
EOL'

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable qubes_hcl_scraper
sudo systemctl start qubes_hcl_scraper

# Configure Nginx
sudo bash -c 'cat > /etc/nginx/sites-available/qubes_hcl_scraper << EOL
server {
    listen 80;
    server_name localhost;

    location / {
        proxy_pass http://0.0.0.0:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOL'
sudo ln -s /etc/nginx/sites-available/qubes_hcl_scraper /etc/nginx/sites-enabled/
sudo systemctl restart nginx
