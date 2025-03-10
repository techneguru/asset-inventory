#!/usr/bin/env python3
import nmap
import psycopg2
from datetime import datetime

def scan_network(network_range):
    nm = nmap.PortScanner()
    nm.scan(hosts=network_range, arguments='-O -sS -sU')
    results = []
    for host in nm.all_hosts():
        host_info = {
            'ip_address': host,
            'hostname': nm[host].hostname(),
            'mac_address': nm[host]['addresses'].get('mac', None),
            'vendor': ', '.join(nm[host]['vendor'].values()) if 'vendor' in nm[host] else None,
            'os': nm[host]['osmatch'][0]['name'] if 'osmatch' in nm[host] and nm[host]['osmatch'] else None,
            'layer2_protocols': None,  # Placeholder
            'layer3_protocols': None,  # Placeholder
            'services': None,  # Placeholder for open ports/services
            'open_ports': ', '.join(str(p) for p in nm[host]['tcp'].keys()) if 'tcp' in nm[host] else None
        }
        results.append(host_info)
    return results

def insert_into_db(results):
    conn = psycopg2.connect(
        dbname="asset_inventory",
        user="admin",
        password="admin123",
        host="localhost",
        port="5432"
    )
    cur = conn.cursor()
    for host in results:
        cur.execute("""
            INSERT INTO assets (ip_address, hostname, mac_address, vendor, os, layer2_protocols, layer3_protocols, services, open_ports, timestamp)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
        """, (
            host['ip_address'], host['hostname'], host['mac_address'], host['vendor'], host['os'],
            host['layer2_protocols'], host['layer3_protocols'], host['services'], host['open_ports'],
            datetime.now()
        ))
    conn.commit()
    cur.close()
    conn.close()

if __name__ == "__main__":
    network_range = input("Skriv inn nettverksområde (f.eks. 192.168.1.0/24): ")
    result = scan_network(network_range)
    insert_into_db(result)
    print("✅ Skanning fullført og data lagret i database.")
