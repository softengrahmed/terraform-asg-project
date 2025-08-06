#!/bin/bash
# modules/asg/user_data/app_tier_user_data.sh

# Update system
yum update -y

# Install Java 17 and Maven
yum install -y java-17-amazon-corretto maven git

# Install Docker
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent for application tier
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "namespace": "AWS/EC2/ApplicationTier",
    "metrics_collected": {
      "cpu": {
        "measurement": [
          "cpu_usage_idle",
          "cpu_usage_iowait",
          "cpu_usage_user",
          "cpu_usage_system"
        ],
        "metrics_collection_interval": 60,
        "totalcpu": false
      },
      "disk": {
        "measurement": [
          "used_percent"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/application.log",
            "log_group_name": "/aws/ec2/${app_name}/${environment}/application",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "/aws/ec2/${app_name}/${environment}/docker",
            "log_stream_name": "{instance_id}"
          }
        ]
      }
    }
  }
}
EOF

# Start CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
  -s

# Create application directories
mkdir -p /opt/app/{logs,config,data}
chown ec2-user:ec2-user /opt/app -R

# Install application monitoring tools
yum install -y htop iotop

# Install and configure Node Exporter for Prometheus monitoring
wget https://github.com/prometheus/node_exporter/releases/latest/download/node_exporter-1.6.1.linux-amd64.tar.gz
tar xvfz node_exporter-1.6.1.linux-amd64.tar.gz
cp node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/
useradd --no-create-home --shell /bin/false node_exporter
chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create node_exporter systemd service
cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

# Configure application environment
cat > /opt/app/config/app.properties << EOF
# Application Configuration
app.name=${app_name}
app.environment=${environment}
app.port=8080
app.log.level=INFO

# Database Configuration (placeholder)
db.host=\${DB_HOST}
db.port=\${DB_PORT}
db.name=\${DB_NAME}
db.user=\${DB_USER}
db.password=\${DB_PASSWORD}

# Cache Configuration
cache.enabled=true
cache.ttl=3600
EOF

# Install SSM agent
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Create health check script
cat > /opt/app/health-check.sh << 'EOF'
#!/bin/bash
# Simple health check for load balancer
curl -f http://localhost:8080/health > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "Application is healthy"
    exit 0
else
    echo "Application is unhealthy"
    exit 1
fi
EOF

chmod +x /opt/app/health-check.sh

# Set up cron job for cleanup
echo "0 2 * * * root find /opt/app/logs -name '*.log' -mtime +7 -delete" >> /etc/crontab

# Configure JVM options for better performance
cat > /opt/app/config/jvm.options << 'EOF'
-Xms1g
-Xmx2g
-XX:+UseG1GC
-XX:G1HeapRegionSize=16m
-XX:+UseG1GC
-XX:+UnlockExperimentalVMOptions
-XX:+EnableJVMCI
-XX:+UseJVMCICompiler
-XX:+DisableExplicitGC
-Djava.awt.headless=true
-Dfile.encoding=UTF-8
-Djava.security.egd=file:/dev/./urandom
EOF

echo "Application tier instance setup completed at $(date)" >> /var/log/user-data.log