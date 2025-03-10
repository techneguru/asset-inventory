#!/bin/bash

set -e  # Avbryt skriptet ved første feil
set -o pipefail  # Fang feil i piped kommandoer

# Funksjon for systemoppdatering og installasjon av nødvendige pakker
install_packages() {
    echo "🔹 Sjekker internettforbindelse..."
    if ! ping -c 1 google.com &>/dev/null; then
        echo "❌ Ingen internettforbindelse! Sjekk nettverket og prøv igjen."
        exit 1
    fi
    
    echo "🔹 Oppdaterer systemet og installerer nødvendige pakker..."
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y docker.io docker-compose nmap python3-pip git curl graphviz jq
}

# Funksjon for å konfigurere Docker og nettverksinnstillinger
configure_docker() {
    echo "🔹 Konfigurerer Docker..."
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    echo '{
      "registry-mirrors": ["https://mirror.gcr.io"],
      "dns": ["8.8.8.8", "8.8.4.4"]
    }' | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
    sudo systemctl enable docker
    
    echo "🔹 Sjekker Docker-tilgang..."
    if ! sudo docker ps &>/dev/null; then
        echo "❌ Bruker har ikke tilgang til Docker. Legger til i docker-gruppen..."
        sudo usermod -aG docker $USER
        echo "🔹 Logg ut og inn igjen eller kjør: exec su - $USER"
    fi
}

# Funksjon for å sette opp PostgreSQL med utvidet skjema
deploy_postgresql() {
    echo "🔹 Installerer PostgreSQL..."
    sudo docker rm -f postgres || true
    sudo docker volume prune -f
    
    for i in {1..3}; do
        sudo docker pull postgres:latest && break
        echo "⚠️ Feil ved pulling av PostgreSQL, prøver igjen ($i/3)..."
        sleep 5
    done

    sudo docker run -d \
      --name postgres \
      -e POSTGRES_USER=admin \
      -e POSTGRES_PASSWORD=admin123 \
      -e POSTGRES_DB=asset_inventory \
      -p 5432:5432 \
      postgres:latest
    
    echo "🔹 Oppretter database-tabeller med utvidet OSI-informasjon..."
    sleep 10
    sudo docker exec -i postgres psql -U admin -d asset_inventory <<EOF
CREATE TABLE IF NOT EXISTS assets (
    id SERIAL PRIMARY KEY,
    ip_address VARCHAR(45),
    hostname VARCHAR(255),
    mac_address VARCHAR(17),
    vendor VARCHAR(255),
    os VARCHAR(255),
    layer2_protocols VARCHAR(255),
    layer3_protocols VARCHAR(255),
    services TEXT,
    open_ports TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
EOF
}

# Funksjon for å installere NetBox
deploy_netbox() {
    echo "🔹 Installerer NetBox..."
    if [ ! -d "netbox-docker" ]; then
        sudo git clone -b release https://github.com/netbox-community/netbox-docker.git
    fi
    cd netbox-docker || exit 1
    sudo docker-compose up -d
    cd ..
}

# Funksjon for å installere Grafana
deploy_grafana() {
    echo "🔹 Installerer Grafana..."
    sudo docker rm -f grafana || true
    for i in {1..3}; do
        sudo docker pull grafana/grafana:latest && break
        echo "⚠️ Feil ved pulling av Grafana, prøver igjen ($i/3)..."
        sleep 5
    done
    sudo docker run -d --name grafana -p 3000:3000 grafana/grafana
}

# Funksjon for å installere Python-moduler
install_python_modules() {
    echo "🔹 Installerer Python-moduler..."
    for i in {1..3}; do
        sudo pip3 install xmltodict psycopg2-binary pandas graphviz flask && break
        echo "⚠️ Feil ved installasjon, prøver igjen ($i/3)..."
        sleep 5
    done
}

# Funksjon for å laste ned og plassere Python-skript
fetch_scripts() {
    echo "🔹 Laster ned Python-skript fra repo..."
    sudo rm -f /usr/local/bin/scan_and_import.py /usr/local/bin/web_ui.py /usr/local/bin/index.html

    if sudo curl -fLo /usr/local/bin/scan_and_import.py https://raw.githubusercontent.com/techneguru/asset-inventory/main/scan_and_import.py &&
       sudo curl -fLo /usr/local/bin/web_ui.py https://raw.githubusercontent.com/techneguru/asset-inventory/main/web_ui.py &&
       sudo curl -fLo /usr/local/bin/index.html https://raw.githubusercontent.com/techneguru/asset-inventory/main/index.html; then
        echo "✅ Python-skript lastet ned og lagret i /usr/local/bin/"
        sudo chmod +x /usr/local/bin/*.py
    else
        echo "❌ Feil ved nedlasting av ett eller flere filer. Kontroller GitHub-repoet og nettverk!"
        exit 1
    fi
}

# Funksjon for å verifisere tjenester
verify_services() {
    echo "🔹 Verifiserer tjenester..."
    for service in postgres grafana netbox; do
        if ! sudo docker ps --format '{{.Names}}' | grep -q "$service"; then
            echo "❌ $service kjører ikke! Sjekk med: sudo docker logs $service"
            exit 1
        fi
    done
}

# Hovedmeny
while true; do
    echo "\n🔹 Velg en operasjon:"
    echo "1) Installer systempakker"
    echo "2) Konfigurer Docker"
    echo "3) Installer PostgreSQL med utvidet skjema"
    echo "4) Installer NetBox"
    echo "5) Installer Grafana"
    echo "6) Installer Python-moduler"
    echo "7) Last ned og plasser Python-skript"
    echo "8) Verifiser tjenester"
    echo "9) Avslutt"
    read -p "Velg en handling (1-9): " choice
    
    case $choice in
        1) install_packages ;;
        2) configure_docker ;;
        3) deploy_postgresql ;;
        4) deploy_netbox ;;
        5) deploy_grafana ;;
        6) install_python_modules ;;
        7) fetch_scripts ;;
        8) verify_services ;;
        9) exit 0 ;;
        *) echo "❌ Ugyldig valg!" ;;
    esac

done
