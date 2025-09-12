# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "three-tier-vpc-${var.environment}"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.environment}"
  }
}

# Public Subnets (for Web Tier and NAT)
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = element(data.aws_availability_zones.available.names, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}-${var.environment}"
  }
}

# Private Subnets (for App Tier)
resource "aws_subnet" "private_app" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10 + count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private-app-subnet-${count.index + 1}-${var.environment}"
  }
}

# Isolated Subnets (for Data Tier / RDS)
resource "aws_subnet" "private_db" {
  count = 2

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 20 + count.index)
  availability_zone = element(data.aws_availability_zones.available.names, count.index)

  tags = {
    Name = "private-db-subnet-${count.index + 1}-${var.environment}"
  }
}

# Data Source: Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  count  = 2
  domain = "vpc"
}

# NAT Gateways (one per AZ)
resource "aws_nat_gateway" "nat" {
  count         = 2
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-gw-${count.index + 1}-${var.environment}"
  }

  depends_on = [aws_internet_gateway.gw]
}

# Route Table: Public (Internet access via IGW)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "public-rt-${var.environment}"
  }
}

# Route Table: Private App Subnets (outbound via NAT)
resource "aws_route_table" "private_app_rt" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private-app-rt-${count.index + 1}-${var.environment}"
  }
}

# Route Table: Private DB Subnets (outbound via NAT)
resource "aws_route_table" "private_db_rt" {
  count  = 2
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = "private-db-rt-${count.index + 1}-${var.environment}"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public_assoc" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_app_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private_app[count.index].id
  route_table_id = aws_route_table.private_app_rt[count.index].id
}

resource "aws_route_table_association" "private_db_assoc" {
  count          = 2
  subnet_id      = aws_subnet.private_db[count.index].id
  route_table_id = aws_route_table.private_db_rt[count.index].id
}

# Security Group: ALB (Internet-facing)
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg-${var.environment}"
  description = "Allow HTTP from internet"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg-${var.environment}"
  }
}

# Security Group: Web Tier (behind ALB)
resource "aws_security_group" "web_sg" {
  name        = "web-tier-sg-${var.environment}"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }
  
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "web-tier-sg-${var.environment}"
  }
}

# Security Group: App Tier (private, accessed by ALB)
resource "aws_security_group" "app_sg" {
  name        = "app-tier-sg-${var.environment}"
  description = "Allow traffic from ALB on port 8080"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  

  tags = {
    Name = "app-tier-sg-${var.environment}"
  }
}

# Security Group: Database Tier (RDS)
resource "aws_security_group" "db_sg" {
  name        = "db-tier-sg-${var.environment}"
  description = "Allow MySQL from App Tier only"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web_sg.id, aws_security_group.app_sg.id]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "db-tier-sg-${var.environment}"
  }
}

# Application Load Balancer (Internet-facing)
resource "aws_lb" "web_alb" {
  name               = "web-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "web-alb-${var.environment}"
  }
}

# Target Group for Web Tier
resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg-${var.environment}"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }

  tags = {
    Name = "web-tg-${var.environment}"
  }
}
# Target Group for App Tier (8080)
resource "aws_lb_target_group" "app_tg" {
  name        = "app-tg-${var.environment}"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "instance"

  health_check {
    path                = "/api/data"
    port                = "traffic-port"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "app-tg-${var.environment}"
  }
}

# Listener: Route HTTP 80 to Web Target Group
resource "aws_lb_listener" "web_listener" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# Listener Rule: Route /api/* to App Target Group
resource "aws_lb_listener_rule" "api_rule" {
  listener_arn = aws_lb_listener.web_listener.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

# Launch Template: Web Tier

resource "aws_launch_template" "web_lt" {
  name          = "web-lt-${var.environment}"
  image_id      = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type = var.web_instance_type
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  key_name = "Aug15"

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Serve index.html
cat > /var/www/html/index.html <<'EOL'
<!DOCTYPE html>
<html>
<head>
<title>Contact Form</title>
</head>
<body>
<form id="contactForm">
  <input name="name" placeholder="Name" required />
  <input name="email" placeholder="Email" required />
  <input name="phone" placeholder="Phone" required />
  <button type="submit">Submit</button>
</form>
<script>
document.getElementById('contactForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const formData = new FormData(e.target);
  await fetch("/api/submit", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      name: formData.get("name"),
      email: formData.get("email"),
      phone: formData.get("phone")
    }),
  });
  alert("Submitted!");
});
</script>
</body>
</html>
EOL
EOF
  )
}


# Auto Scaling Group: Web Tier
resource "aws_autoscaling_group" "web_asg" {
  name                = "web-asg-${var.environment}"
  min_size            = var.min_web_instances
  max_size            = var.max_web_instances
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.web_tg.arn]

  tag {
    key                 = "Name"
    value               = "web-server-${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# Launch Template: App Tier
resource "aws_launch_template" "app_lt" {
  name          = "app-lt-${var.environment}"
  image_id      = "ami-00ca32bbc84273381" # Amazon Linux 2 with Node.js support
  instance_type = var.app_instance_type
  depends_on = [aws_db_instance.db]
  user_data = base64encode(<<EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e

# Update system
yum update -y

# Install Node.js and PostgreSQL client
amazon-linux-extras enable postgresql15
yum install -y nodejs npm postgresql15

# Create app folder
mkdir -p /home/ec2-user/app
cd /home/ec2-user/app

# package.json
cat > package.json <<'EOL'
{
  "name": "backend-app",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": { "start": "node server.js" },
  "dependencies": {
    "express": "^4.18.2",
    "pg": "^8.11.0",
    "body-parser": "^1.20.2",
    "cors": "^2.8.5"
  }
}
EOL

# db.js
cat > db.js <<'EOL'
const { Pool } = require('pg');
const pool = new Pool({
  user: process.env.PGUSER,
  host: process.env.PGHOST,
  database: process.env.PGDATABASE,
  password: process.env.PGPASSWORD,
  port: 5432,
});
module.exports = { query: (text, params) => pool.query(text, params) };
EOL

# server.js
cat > server.js <<'EOL'
const express = require('express');
const bodyParser = require('body-parser');
const db = require('./db');

const app = express();
app.use(bodyParser.json());

// Ensure table exists on startup
async function initDB() {
  try {
    await db.query(\`CREATE TABLE IF NOT EXISTS contacts (
      id SERIAL PRIMARY KEY,
      name VARCHAR(100),
      email VARCHAR(100),
      phone VARCHAR(20),
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )\`);
    console.log("✅ Contacts table is ready.");
  } catch (err) {
    console.error("❌ Failed to create table:", err.message);
    throw err;
  }
}

app.post('/api/submit', async (req, res) => {
  const { name, email, phone } = req.body;
  try {
    await db.query('INSERT INTO contacts(name,email,phone) VALUES($1,$2,$3)', [name,email,phone]);
    res.send({ message: "Data stored successfully" });
  } catch(err) {
    console.error(err);
    res.status(500).send({ error: "DB Insert failed" });
  }
});

app.listen(8080, () => console.log("✅ Server running on port 8080"));
EOL

# Install dependencies
npm install

# Wait for RDS to be reachable (max 10 minutes)
echo "⏳ Waiting for RDS database at ${aws_db_instance.db.address} to be ready..."
for i in {1..60}; do
  if pg_isready -h ${aws_db_instance.db.address} -p 5432 -U ${var.db_username} -d myapp; then
    echo "✅ Database is ready!"
    break
  else
    echo "Attempt $i: Database not ready... Retrying in 10s"
    sleep 10
  fi
done

# If we get here after 60 attempts, exit with error
if ! pg_isready -h ${aws_db_instance.db.address} -p 5432 -U ${var.db_username} -d myapp; then
  echo "❌ FATAL: RDS database did not become available within 10 minutes."
  exit 1
fi

# Create systemd service
cat > /etc/systemd/system/nodeapp.service <<'EOL'
[Unit]
Description=Node.js App
After=network.target

[Service]
ExecStart=/usr/bin/node /home/ec2-user/app/server.js
Restart=always
User=ec2-user
Environment=PGUSER=${var.db_username}
Environment=PGPASSWORD=${var.db_password}
Environment=PGHOST=${aws_db_instance.db.address}
Environment=PGDATABASE=myapp
StandardOutput=file:/var/log/nodeapp.log
StandardError=file:/var/log/nodeapp.log

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable nodeapp
systemctl start nodeapp

echo "✅ Node.js application started successfully."
EOF
)
}

# Auto Scaling Group: App Tier
resource "aws_autoscaling_group" "app_asg" {
  name                = "app-asg-${var.environment}"
  min_size            = var.min_app_instances
  max_size            = var.max_app_instances
  desired_capacity    = 1
  vpc_zone_identifier = aws_subnet.private_app[*].id

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.app_tg.arn]

  tag {
    key                 = "Name"
    value               = "app-server-${var.environment}"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# DB Subnet Group + RDS
resource "aws_db_subnet_group" "db_subnet" {
  name       = "db-subnet-${var.environment}"
  subnet_ids = aws_subnet.private_db[*].id

  tags = {
    Name = "db-subnet-group-${var.environment}"
  }
}

resource "aws_db_instance" "db" {
  identifier           = "three-tier-db-${var.environment}"
  engine               = "postgres"
  engine_version       = "15"
  instance_class       = var.db_instance_class
  allocated_storage    = 20
  storage_encrypted    = true
  publicly_accessible  = false
  skip_final_snapshot  = true
  port                 = 5432
  db_subnet_group_name = aws_db_subnet_group.db_subnet.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  username = var.db_username
  password = var.db_password
  db_name  = "myapp"

  depends_on = [aws_internet_gateway.gw]
}
  

