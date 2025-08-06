#!/bin/bash
# modules/asg/user_data/custom_user_data.sh

# Update system
yum update -y

# Install essential tools
yum install -y \
    python3 \
    python3-pip \
    git \
    wget \
    curl \
    jq \
    unzip \
    htop \
    iotop \
    awscli

# Install Docker and Docker Compose
yum install -y docker
systemctl start docker
systemctl enable docker
usermod -a -G docker ec2-user

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install CloudWatch agent
yum install -y amazon-cloudwatch-agent

# Configure CloudWatch agent for custom workloads
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
  "metrics": {
    "namespace": "AWS/EC2/Custom",
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
          "used_percent",
          "inodes_free"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "diskio": {
        "measurement": [
          "io_time",
          "read_bytes",
          "write_bytes",
          "reads",
          "writes"
        ],
        "metrics_collection_interval": 60,
        "resources": [
          "*"
        ]
      },
      "mem": {
        "measurement": [
          "mem_used_percent",
          "mem_available_percent"
        ],
        "metrics_collection_interval": 60
      },
      "netstat": {
        "measurement": [
          "tcp_established",
          "tcp_time_wait"
        ],
        "metrics_collection_interval": 60
      },
      "processes": {
        "measurement": [
          "running",
          "sleeping",
          "dead"
        ]
      }
    }
  },
  "logs": {
    "logs_collected": {
      "files": {
        "collect_list": [
          {
            "file_path": "/var/log/custom-app.log",
            "log_group_name": "/aws/ec2/${app_name}/${environment}/custom",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/docker.log",
            "log_group_name": "/aws/ec2/${app_name}/${environment}/docker",
            "log_stream_name": "{instance_id}"
          },
          {
            "file_path": "/var/log/cron.log",
            "log_group_name": "/aws/ec2/${app_name}/${environment}/cron",
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
mkdir -p /opt/custom/{apps,data,logs,config,scripts}
chown ec2-user:ec2-user /opt/custom -R

# Install Prometheus Node Exporter
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

# Install Python packages for data processing
pip3 install \
    pandas \
    numpy \
    boto3 \
    redis \
    psycopg2-binary \
    requests \
    schedule

# Install Kubernetes tools (if needed for custom workloads)
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Terraform (for infrastructure automation)
wget https://releases.hashicorp.com/terraform/1.12.2/terraform_1.12.2_linux_amd64.zip
unzip terraform_1.12.2_linux_amd64.zip
mv terraform /usr/local/bin/
rm terraform_1.12.2_linux_amd64.zip

# Create custom monitoring script
cat > /opt/custom/scripts/custom-monitor.py << 'EOF'
#!/usr/bin/env python3
import boto3
import json
import time
import subprocess
import os

def send_custom_metrics():
    """Send custom metrics to CloudWatch"""
    cloudwatch = boto3.client('cloudwatch')
    
    # Get instance ID
    instance_id = subprocess.check_output(['curl', '-s', 'http://169.254.169.254/latest/meta-data/instance-id']).decode('utf-8')
    
    # Get disk usage
    result = subprocess.run(['df', '-h', '/'], capture_output=True, text=True)
    disk_usage = result.stdout.split('\n')[1].split()[4].rstrip('%')
    
    # Send metric
    cloudwatch.put_metric_data(
        Namespace='Custom/Application',
        MetricData=[
            {
                'MetricName': 'DiskUsagePercent',
                'Dimensions': [
                    {
                        'Name': 'InstanceId',
                        'Value': instance_id
                    },
                ],
                'Value': float(disk_usage),
                'Unit': 'Percent'
            },
        ]
    )

if __name__ == "__main__":
    send_custom_metrics()
EOF

chmod +x /opt/custom/scripts/custom-monitor.py

# Create systemd service for custom monitoring
cat > /etc/systemd/system/custom-monitor.service << 'EOF'
[Unit]
Description=Custom Monitoring Service
After=network.target

[Service]
Type=simple
User=ec2-user
ExecStart=/usr/bin/python3 /opt/custom/scripts/custom-monitor.py
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl start custom-monitor
systemctl enable custom-monitor

# Install SSM agent
yum install -y amazon-ssm-agent
systemctl start amazon-ssm-agent
systemctl enable amazon-ssm-agent

# Create custom health check
cat > /opt/custom/scripts/health-check.sh << 'EOF'
#!/bin/bash
# Custom health check script

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 90 ]; then
    echo "UNHEALTHY: Disk usage is ${DISK_USAGE}%"
    exit 1
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [ $MEM_USAGE -gt 90 ]; then
    echo "UNHEALTHY: Memory usage is ${MEM_USAGE}%"
    exit 1
fi

# Check if required services are running
if ! systemctl is-active --quiet docker; then
    echo "UNHEALTHY: Docker service is not running"
    exit 1
fi

if ! systemctl is-active --quiet node_exporter; then
    echo "UNHEALTHY: Node Exporter service is not running"
    exit 1
fi

echo "HEALTHY: All checks passed"
exit 0
EOF

chmod +x /opt/custom/scripts/health-check.sh

# Set up log rotation
cat > /etc/logrotate.d/custom-app << 'EOF'
/opt/custom/logs/*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 0644 ec2-user ec2-user
}
EOF

# Set up cleanup cron job
echo "0 3 * * * root find /opt/custom/logs -name '*.log.*' -mtime +30 -delete" >> /etc/crontab
echo "0 4 * * * root docker system prune -f" >> /etc/crontab

echo "Custom tier instance setup completed at $(date)" >> /var/log/user-data.log