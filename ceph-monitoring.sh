#!/bin/bash

groupadd --system prometheus
useradd -s /sbin/nologin --system -g prometheus prometheus
mkdir /var/lib/prometheus

for i in rules rules.d files_sd; do
 mkdir -p /etc/prometheus/${i}
done

apt -y install wget
mkdir -p /tmp/prometheus && cd /tmp/prometheus
curl -s https://api.github.com/repos/prometheus/prometheus/releases/latest | grep browser_download_url | grep linux-amd64 | cut -d '"' -f 4 | wget -i -
tar xvf prometheus*.tar.gz

cd prometheus*/
mv prometheus promtool /usr/local/bin/
mv prometheus.yml /etc/prometheus/prometheus.yml
mv consoles/ console_libraries/ /etc/prometheus/

cd ~/
rm -rf /tmp/prometheus

echo "[Unit]
Description=Prometheus
Documentation=https://prometheus.io/docs/introduction/overview/
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
Environment="GOMAXPROCS=2"
User=prometheus
Group=prometheus
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/prometheus \
--config.file=/etc/prometheus/prometheus.yml \
--storage.tsdb.path=/var/lib/prometheus \
--storage.tsdb.retention.time=90d \
--web.console.templates=/etc/prometheus/consoles \
--web.console.libraries=/etc/prometheus/console_libraries \
--web.listen-address=0.0.0.0:9090 \
--web.external-url=

SyslogIdentifier=prometheus
Restart=always

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/prometheus.service

chown -R prometheus:prometheus /etc/prometheus
chown -R prometheus:prometheus /var/lib/prometheus

for i in rules rules.d files_sd; do
  chmod -R 775 /etc/prometheus/${i}
done

systemctl enable prometheus
systemctl start prometheus

apt install -y gnupg2 curl software-properties-common
curl https://packages.grafana.com/gpg.key | sudo apt-key add -
add-apt-repository "deb https://packages.grafana.com/oss/deb stable main"

apt update
apt -y install grafana

systemctl enable --now grafana-server

mkdir /etc/ceph

apt install -y docker.io
git clone https://github.com/digitalocean/ceph_exporter.git
docker build -t ceph_exporter ceph_exporter

echo "
  - job_name: 'ceph-exporter'
    static_configs:
    - targets: ['localhost:9128']
      labels:
        alias: ceph-exporter
" >> /etc/prometheus/prometheus.yml

systemctl daemon-reload
systemctl restart prometheus
