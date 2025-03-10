from flask import Flask, render_template_string
import psycopg2

app = Flask(__name__)

def get_assets():
    conn = psycopg2.connect(
        dbname="asset_inventory",
        user="admin",
        password="admin123",
        host="localhost",
        port="5432"
    )
    cur = conn.cursor()
    cur.execute("SELECT * FROM assets ORDER BY last_scanned DESC LIMIT 50;")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows

@app.route("/")
def index():
    assets = get_assets()
    return render_template_string("""
        <h1>Asset Inventory</h1>
        <table border="1">
            <tr>
                <th>ID</th><th>IP Address</th><th>MAC Address</th><th>Hostname</th>
                <th>Vendor</th><th>OS</th><th>Layer2 Protocols</th><th>Layer3 Protocols</th>
                <th>Services</th><th>Open Ports</th><th>Last Scanned</th>
            </tr>
            {% for row in assets %}
            <tr>
                {% for cell in row %}
                <td>{{ cell }}</td>
                {% endfor %}
            </tr>
            {% endfor %}
        </table>
    """, assets=assets)

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5000, debug=True)
