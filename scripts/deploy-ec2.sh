#!/bin/bash


AWS_REGION="us-west-2"
# AMI_ID="ami-021c478d943abe2da" 
AMI_ID="ami-00c257e12d6828491" 
# AMI_ID="ami-04b4f1a9cf54c11d0" 
# ami-04b4f1a9cf54c11d0

INSTANCE_TYPE="t2.micro"
# INSTANCE_TYPE="t4g.micro"
KEY_NAME="bookshop-key"
SECURITY_GROUP_ID="sg-035d78de7367db290"

# 3️⃣ create EC2 instance
INSTANCE_ID=$(aws ec2 run-instances \
    --region us-west-2 \
    --image-id $AMI_ID \
    --count 1 \
    --instance-type $INSTANCE_TYPE \
    --key-name $KEY_NAME \
    --security-group-ids $SECURITY_GROUP_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=bookshop-ec2}]' \
    --query "Instances[0].InstanceId" \
    --output text)

echo "EC2 Instance Created: $INSTANCE_ID"


aws ec2 wait instance-running --region $AWS_REGION --instance-ids $INSTANCE_ID
echo "EC2 Instance is running."

sleep 10

# 5️⃣ get EC2 public IP
# EC2_PUBLIC_IP=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
EC2_PUBLIC_IP=$(aws ec2 describe-instances --region $AWS_REGION --instance-ids $INSTANCE_ID --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
  
echo "EC2 Public IP: $EC2_PUBLIC_IP"
echo "$INSTANCE_ID" > ec2-instance-id.env
echo "$EC2_PUBLIC_IP" > ec2_ip.txt
echo "EC2_PUBLIC_IP=$EC2_PUBLIC_IP" >> "$GITHUB_ENV"

if [[ ! -f ~/.ssh/bookshop-key.pem ]]; then
  chmod 400 ~/.ssh/bookshop-key.pem
fi
echo "🚀 Checking SSH Key..."
ls -lah ~/.ssh/

echo "Waiting for SSH to be available..."
sleep 5

ssh -o StrictHostKeyChecking=no -i ~/.ssh/bookshop-key.pem ubuntu@$EC2_PUBLIC_IP << EOF
  set -e

  echo "📦 Updating system packages..."
  sudo apt update -y && sudo apt upgrade -y
  
  echo "📦 Installing curl..."
  sudo apt install -y curl

  echo "📦 Installing Git..."
  sudo apt install -y git || echo "⚠️ Git installation failed"
  git --version || echo "❌ Git installation verification failed"

  echo "📦 Installing MySQL (MariaDB 10.5)..."
  sudo apt install -y mariadb-server
  sudo systemctl enable --now mariadb

  echo "✅ Git Version: \$(git --version || echo '❌ Git installation failed!')"
  echo "✅ MySQL Version: \$(mysql --version || echo '❌ MySQL installation failed!')"

  echo "🚀 Setup Complete!"
EOF
#   echo "📦 Installing MySQL (MariaDB 10.5)..."
#   sudo apt install -y mariadb-server
#   sudo systemctl enable --now mariadb

# 6️⃣ connect SSH
echo "✅ EC2 setup complete!"
echo "To connect via SSH: ssh -i ~/.ssh/$KEY_NAME.pem ubuntu@$EC2_PUBLIC_IP"