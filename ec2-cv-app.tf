##########################################################
# Online Resume System - EC2 LAMP Deployment
# Single t3.micro instance running Apache+PHP+MariaDB,
# deployed from the GitHub repo (newCVproject/ folder).
##########################################################

variable "db_password" {
  description = "Password for the cvapp MySQL user"
  type        = string
  sensitive   = true
  default     = "ChangeMe123!CV"
}

variable "repo_url" {
  description = "Git repository URL containing newCVproject/"
  type        = string
  default     = "https://github.com/fendi-321/Serverless-Architecture.git"
}

variable "my_ip" {
  description = "Your public IP (CIDR) allowed to SSH into the instance"
  type        = string
  default     = "110.159.30.217/32"
}

variable "key_pair_name" {
  description = "Existing EC2 key pair name for SSH access"
  type        = string
  default     = "web server"
}

# =====================================================
# Networking (minimal VPC - none exists in this account)
# =====================================================
resource "aws_vpc" "cv_app_vpc" {
  cidr_block           = "10.20.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "cv-app-vpc"
  }
}

resource "aws_subnet" "cv_app_public_subnet" {
  vpc_id                  = aws_vpc.cv_app_vpc.id
  cidr_block              = "10.20.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "cv-app-public-subnet"
  }
}

resource "aws_internet_gateway" "cv_app_igw" {
  vpc_id = aws_vpc.cv_app_vpc.id

  tags = {
    Name = "cv-app-igw"
  }
}

resource "aws_route_table" "cv_app_public_rt" {
  vpc_id = aws_vpc.cv_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cv_app_igw.id
  }

  tags = {
    Name = "cv-app-public-rt"
  }
}

resource "aws_route_table_association" "cv_app_public_rta" {
  subnet_id      = aws_subnet.cv_app_public_subnet.id
  route_table_id = aws_route_table.cv_app_public_rt.id
}

# =====================================================
# Security Group
# =====================================================
resource "aws_security_group" "cv_app_sg" {
  name        = "cv-app-sg"
  description = "Allow HTTP/HTTPS from anywhere, SSH from my IP only"
  vpc_id      = aws_vpc.cv_app_vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "cv-app-sg"
  }
}

# =====================================================
# IAM Role for EC2 (allow S3 backup uploads)
# =====================================================
resource "aws_iam_role" "cv_app_ec2_role" {
  name = "cv-app-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "cv_app_s3_backup_policy" {
  name = "cv-app-s3-backup-policy"
  role = aws_iam_role.cv_app_ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${aws_s3_bucket.cv_app_backup_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "cv_app_instance_profile" {
  name = "cv-app-instance-profile"
  role = aws_iam_role.cv_app_ec2_role.name
}

# Allow browser-based access via AWS Systems Manager Session Manager
# (no need to open port 22 / no SSH key required from the console)
resource "aws_iam_role_policy_attachment" "cv_app_ssm_policy" {
  role       = aws_iam_role.cv_app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}


# =====================================================
# S3 Bucket for DB backups
# =====================================================
resource "random_id" "backup_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "cv_app_backup_bucket" {
  bucket        = "cv-app-db-backups-${random_id.backup_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "cv_app_backup_bucket" {
  bucket = aws_s3_bucket.cv_app_backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# =====================================================
# EC2 Instance
# =====================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "cv_app_server" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.cv_app_public_subnet.id
  vpc_security_group_ids      = [aws_security_group.cv_app_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.cv_app_instance_profile.name
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }


  user_data = templatefile("${path.module}/templates/user_data.sh.tpl", {
    db_password    = var.db_password
    repo_url       = var.repo_url
    backup_bucket  = aws_s3_bucket.cv_app_backup_bucket.bucket
  })

  tags = {
    Name = "cv-app-server"
  }
}

resource "aws_eip" "cv_app_eip" {
  instance = aws_instance.cv_app_server.id
  domain   = "vpc"

  tags = {
    Name = "cv-app-eip"
  }
}

output "cv_app_public_url" {
  value = "http://${aws_eip.cv_app_eip.public_ip}"
}

output "cv_app_ssh_command" {
  value = "ssh -i \"web server.pem\" ec2-user@${aws_eip.cv_app_eip.public_ip}"
}

output "cv_app_backup_bucket_name" {
  value = aws_s3_bucket.cv_app_backup_bucket.id
}
