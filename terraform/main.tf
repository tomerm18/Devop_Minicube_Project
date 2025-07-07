provider "aws" {
  region = "us-east-1" # You can change this to your preferred region
}

# Create a VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "devops-project-vpc"
  }
}

# Create a public subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Ensure instances get a public IP
  availability_zone       = "us-east-1a" # Change if needed

  tags = {
    Name = "devops-project-public-subnet"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "devops-project-igw"
  }
}

# Create a route table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # Route all traffic to the Internet Gateway
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "devops-project-public-rt"
  }
}

# Associate the route table with our public subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Create a security group to allow required traffic
resource "aws_security_group" "minikube_sg" {
  name        = "minikube-sg"
  description = "Allow SSH and NodePort traffic"
  vpc_id      = aws_vpc.main.id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # WARNING: Open to the world. For production, restrict this to your IP.
  }

  # Allow access to our web app's NodePort
  ingress {
    from_port   = 30080
    to_port     = 30080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create an EC2 instance to run Minikube
resource "aws_instance" "minikube_server" {
  instance_type          = "t3.medium" # Minikube needs at least 2 CPUs and 2GB of memory
  ami                    = "ami-020cba7c55df1f615" # Ubuntu 20.04 LTS in us-east-1. Change if you use a different region.
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.minikube_sg.id]
  key_name               = "devops-project-key" # Name of the key pair

  # User data script to install everything on boot
  user_data = <<-EOF
              #!/bin/bash
              # Update packages
              apt-get update -y
              
              # Install Docker
              apt-get install -y docker.io
              systemctl start docker
              systemctl enable docker
              usermod -aG docker ubuntu

              # Install kubectl
              curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
              install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

              # Install Minikube
              curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
              install minikube /usr/local/bin/

              # Start Minikube (run as the ubuntu user)
              sudo -u ubuntu minikube start --driver=docker --force
              EOF

  tags = {
    Name = "Minikube-Server-DevOps-Project"
  }
}

# Create and manage the SSH key pair in AWS
resource "aws_key_pair" "deployer_key" {
  key_name   = "devops-project-key"
  # This public key must correspond to the private key in the GitHub secret
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiyfGhUfelZD2UrJvwfZik0dzCPypFQhDSkQtcSqEzYnWLfrqxsyRNvxSj78yms1wrY2agelhcpEcUM2vO56AJdrf5tsPkZ69C4TDliExztCRCqIyprGNZOuAtJj1NLrtfdct7PmGKLl8xPw+Ecc3q1k/kuHFw4CY+UbF1vdajFNhKwJ6wJpt2SbZEsAJo8BuzkpFx0M520U5ppYxNzcg8tG2QnnMcahrSI41pLt1xnYLP261/8ekXPZfS1oHTltuunXj46gmyVpTZVE1TQusYVgt9bankIsxJZ6PJA6qAXW3oLxgl3lElM2AzLzWbJzT2OyJyw9GBFOz2O9LvIwfCu+tF/H8iN4LTY/CCx+YWivpjepi+14NwSJ62WokOUU6jk0LpgnVWP7AJAX0Ja7pQav573y0UDv7WU+fpeqnVXyKsfMTGVZpsMMDXm66PmjUVNSVsh7qDL1rkCEI7SUMx4gEW3+KKaQu4UhND0spso2y1I7jA9lnXw2B6uUSA7IHDqDlHm5WkoaUa1u0VwlS2zb+n0n7tC53MfKZzjNZaCsvXiInWrSAfqvYRbY3NmqD/LLEJ6O+6JjBrhdstJTcMQ6hqyTcbOvHqSSknBof4VFEprOppYMclLd2uFR/yWhGR8dVvQtMidXv33++sfcjGHY7IP+Xve/nYbMwffyQxiQ== simonj@Simons-MacBook-Pro.local" # Replace with your actual public SSH key
}

# Output the public IP of the EC2 instance
output "instance_public_ip" {
  value = aws_instance.minikube_server.public_ip
}
