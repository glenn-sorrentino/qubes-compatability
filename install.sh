#!/bin/bash

# Update package lists and install required packages
sudo apt update && sudo apt -y dist-upgrade
sudo apt install -y python3 python3-pip python3-venv nginx

# Create a virtual environment
python3 -m venv venv

# Activate the virtual environment
source venv/bin/activate

# Install required Python libraries
pip install beautifulsoup4 requests gunicorn Flask

# Create the Flask application file
cat > app.py << EOL
from flask import Flask, render_template
from bs4 import BeautifulSoup
import requests

app = Flask(__name__)

@app.route('/')
def qubes_hcl_scraper():
    url = 'https://www.qubes-os.org/hcl/'
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    table = soup.find('table', {'class': 'table table-striped'})

    headers = [header.text.strip() for header in table.findAll('th')]
    rows = table.findAll('tr')[1:]  # Skip the header row

    compatible_laptops = []

    for row in rows:
        cells = row.findAll('td')
        cell_values = [cell.text.strip() for cell in cells]

        # Check if all features are marked "yes" or "Yes" for the latest Qubes version
        if cell_values[1].lower() == "yes" and all(value.lower() == "yes" for value in cell_values[3:7]):
            compatible_laptops.append(cell_values)

    return render_template('index.html', headers=headers, laptops=compatible_laptops)

if __name__ == '__main__':
    app.run()

EOL

# Create an index.html file
mkdir templates
cat > templates/index.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Qubes HCL Scraper</title>
</head>
<body>
    <table>
        <thead>
            <tr>
                {% for header in headers %}
                    <th>{{ header }}</th>
                {% endfor %}
            </tr>
        </thead>
        <tbody>
            {% for laptop in laptops %}
                <tr>
                    <td>{{ laptop[0] }}</td>
                    <td>{{ laptop[1] }}</td>
                    <td>{{ laptop[2] }}</td>
                    <td>{{ laptop[3] }}</td>
                    <td>{{ laptop[4] }}</td>
                    <td>{{ laptop[5] }}</td>
                </tr>
            {% else %}
                <tr>
                    <td colspan="{{ headers|length }}">No compatible laptops found</td>
                </tr>
            {% endfor %}
        </tbody>
    </table>
</body>
</html>
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
sudo systemctl
