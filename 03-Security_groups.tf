#--------------------- SECURITY GROUP CONFIGURATION --------------------

// public security group
resource "aws_security_group" "public-sg" {
  name   = "tf-pub-sg-1"
  vpc_id = aws_vpc.k8s-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name                                            = "pub-sg-1"
    provision                                       = "terraform"
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
  }
}

//Nat gateway security group
resource "aws_security_group" "Nat-sg" {
  description = "allow all incoming traffic"
  name        = "nat-sg-1"
  vpc_id      = aws_vpc.k8s-vpc.id
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name                                            = "nat-sg-1"
    provision                                       = "terraform"
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
  }
}