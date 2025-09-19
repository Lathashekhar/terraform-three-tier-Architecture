# 🚀 Terraform Three-Tier Architecture on AWS

This project provisions a **highly available three-tier architecture** on **AWS** using **Terraform**. It follows Infrastructure as Code (IaC) principles for scalability, repeatability, and automation.

---

## 🏗️ Architecture Overview

The infrastructure consists of **three layers**:

1. **Presentation Layer (Web Tier)**

   * Public Subnets with EC2 instances
   * Application Load Balancer (ALB) for routing

2. **Application Layer (App Tier)**

   * Private Subnets with Auto Scaling EC2 instances
   * Handles business logic

3. **Data Layer (DB Tier)**

   * Private Subnets with Amazon RDS (PostgreSQL/MySQL)
   * Multi-AZ for high availability

Other components:

* **VPC with public/private subnets** across multiple AZs
* **NAT Gateway** for secure outbound traffic from private subnets
* **Security Groups & IAM Roles** for fine-grained access control

---

## 🛠️ Tools & Technologies

* **Terraform** – Infrastructure as Code
* **AWS Services** – VPC, EC2, ALB, Auto Scaling, RDS, IAM, NAT Gateway, Subnets, Security Groups
* **GitHub** – Version control & collaboration

---

## 📂 Project Structure

```
terraform-three-tier-Architecture/
├── main.tf              # Root Terraform configuration
├── vpc.tf               # VPC, subnets, gateways
├── ec2.tf               # Web/App tier EC2 instances
├── rds.tf               # Database tier
├── variables.tf         # Input variables
├── outputs.tf           # Outputs (DB endpoint, ALB DNS, etc.)
└── README.md            # Project documentation
```

---

## ⚙️ Deployment Steps

1. Clone the repository:

   ```bash
   git clone https://github.com/Lathashekhar/terraform-three-tier-Architecture.git
   cd terraform-three-tier-Architecture
   ```

2. Initialize Terraform:

   ```bash
   terraform init
   ```

3. Review the plan:

   ```bash
   terraform plan
   ```

4. Apply to provision infrastructure:

   ```bash
   terraform apply -auto-approve
   ```

5. Destroy when no longer needed:

   ```bash
   terraform destroy -auto-approve
   ```

---

## ✅ Key Features

* Automated provisioning of **three-tier AWS architecture**
* **High availability** using multi-AZ deployment
* **Scalable web & app tiers** with Auto Scaling groups
* **Secure DB layer** in private subnets
* Reusable & version-controlled with Terraform


## 🔗 Links

* [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
* [AWS Three-Tier Architecture Reference](https://aws.amazon.com/architecture/)

