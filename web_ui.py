#!/usr/bin/env python3
from flask import Flask, render_template_string
import psycopg2

app = Flask(__name__)

HTML = '''
<!DOCTYPE html>
<html>
<head>
    <title>Asset Inventory</title>
</head>
<body>
    <h1>Asset Inventory</h1>
    <table border="1">
        <tr><th>ID</th><th>IP</th><th>Hostname</th><th>MAC</th><th>Vendor</th><th>OS</th><th>Ports</th><th>Timestamp</th></tr>
        {% for asset in assets %}
        <tr>
            <td>{{ asset[0] }}</td><td>{{ asset[1] }}</td><td>{{ asset[2] }}</td>
            <td>{{ asset[3] }}</td><td>{{ asset[4] }}</td><td>{{ asset[5] }}</td>
            <td>{{ asset[9] }}</td><td>{{ asset[10] }}</td>
        </tr>
        {% endfor %}
    </table>
</body>
</html>
'''

def get_assets():
    conn = psycopg2.connect(
        dbname="asset_inventory",
        user="admin",
        password="admin123",
        host="localhost",
        port="5432"
    )
    cur = conn.cursor()
    cur.execute("SELECT * FROM assets ORDER BY timestamp DESC LIMIT 50;")
    data = cur.fetchall()
    cur.close()
    conn.close()
    return data

@app.route('/')
def index():
    return render_template_string(HTML, assets=get_assets())

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080, debug=True)
