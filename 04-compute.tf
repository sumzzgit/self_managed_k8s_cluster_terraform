#-------------------- VARIABLES ----------------------

// NAT instance AMI ID
variable "NAT_AMI_ID" {
  type        = string
  description = "AMI ID for the NAT instance based on region - default is ap-south-1"
  default     = "ami-0a493f6d8c0886281"
}

// NAT instance type 
variable "NAT_instance_type" {
  type    = string
  default = "t2.micro"
}

// master node instance type
variable "master_node_instance_type" {
  type    = string
  default = "t2.medium"
}

// worker node instance type
variable "worker_node_instance_type" {
  type    = string
  default = "t2.micro"
}

// pem key name
variable "pem_key_name" {
  type    = string
  default = "kubeadm-key"
}

// PEM key secret manager arn
variable "pem_key_arn" {
  type = string
}

// kubernets cluster name 
variable "k8s_cluster_name" {
  type        = string
  description = "kubernets cluster required to tag the instances"
  default     = "k8s-test"
}



#---------------------- LOCALS ------------------------

locals {
  pvt_sub_ids = tomap({ "first" = aws_subnet.private_subnets["pvt-sub-1"].id, "second" = aws_subnet.private_subnets["pvt-sub-2"].id })
}



#--------------------- DATA SOURCES --------------------

// fetch amazon linux AMI ID
data "aws_ami" "al2023" {
  owners      = ["amazon"]
  most_recent = true
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

// fetch pem key from the secret manager 
data "aws_secretsmanager_secret_version" "pem_key" {
  secret_id = var.pem_key_arn
}





#-------------------- EC2 INSTANCES ---------------------

//launch NAT instance 
resource "aws_instance" "nat-instance" {
  ami                         = var.NAT_AMI_ID //community ami for the nat instance (ap-south-1)
  associate_public_ip_address = true
  instance_type               = var.NAT_instance_type
  key_name                    = var.pem_key_name
  subnet_id                   = aws_subnet.public_subnets["pub-sub-1"].id
  source_dest_check           = false //this is importatnt for the NAT instance
  vpc_security_group_ids      = [aws_security_group.Nat-sg.id]
  tags = {
    Name      = "Nat-instance"
    provision = "terraform"
  }
}



// launch the master instance in public subnet 
resource "aws_instance" "master-instance" {
  ami                         = data.aws_ami.al2023.image_id
  associate_public_ip_address = true
  instance_type               = var.master_node_instance_type
  key_name                    = var.pem_key_name
  subnet_id                   = aws_subnet.public_subnets["pub-sub-1"].id
  vpc_security_group_ids      = [aws_security_group.public-sg.id]
  iam_instance_profile        = aws_iam_instance_profile.master_profile.name
  tags = {
    Name                                            = "master"
    provision                                       = "terraform"
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = data.aws_secretsmanager_secret_version.pem_key.secret_string
    host        = self.public_ip
  }

  provisioner "file" {
    source      = "${path.module}/basic.sh"
    destination = "/home/ec2-user/basic.sh"
  }

  provisioner "file" {
    source      = "${path.module}/kube-flannel-cm.yml"
    destination = "/home/ec2-user/kube-flannel-cm.yml"
  }

  provisioner "file" {
    content = templatefile("${path.module}/kubeadm_master_conf.tpl", {
      master_public_ip = self.public_ip,
      cluster_name     = var.k8s_cluster_name,
      master_hostname  = self.private_dns
    })
    destination = "/home/ec2-user/kubeadm_master.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/basic.sh",
      "sudo sh /home/ec2-user/basic.sh",
      "sudo kubeadm init --config /home/ec2-user/kubeadm_master.conf --ignore-preflight-errors=NumCPU,Mem",
      "sudo kubeadm token create --print-join-command > /home/ec2-user/kubeadm-join.out",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "sudo yum install git -y",

      "echo '------- applying the flannel network configurations ---------'",
      "sudo mkdir -p /run/flannel && sudo touch /run/flannel/subnet.env",
      "echo 'FLANNEL_NETWORK=10.244.0.0/16' | sudo tee -a /run/flannel/subnet.env",
      "echo 'FLANNEL_SUBNET=10.244.1.0/24' | sudo tee -a /run/flannel/subnet.env",
      "echo 'FLANNEL_MTU=1450' | sudo tee -a /run/flannel/subnet.env",
      "echo 'FLANNEL_IPMASQ=true' | sudo tee -a /run/flannel/subnet.env",
      "kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml",
      "echo 'adding the deplay for the flannel to set completly'",
      "sleep 30",

      "echo '-------- applying aws CCM configurations -------'",
      "kubectl apply -k 'github.com/kubernetes/cloud-provider-aws/examples/existing-cluster/base/?ref=master'",
      "sleep 30",
      "echo 'changing kube flannel config map to enable the IP Masquerading'",
      "kubectl apply -f /home/ec2-user/kube-flannel-cm.yml",
      "kubectl rollout restart ds kube-flannel-ds -n kube-flannel",
      "sleep 30"

    ]
  }

}


// launch the worker nodes in private subnet 
resource "aws_instance" "worker_nodes" {
  for_each                    = local.pvt_sub_ids
  ami                         = data.aws_ami.al2023.image_id
  associate_public_ip_address = true
  instance_type               = var.worker_node_instance_type
  key_name                    = var.pem_key_name
  subnet_id                   = each.value
  vpc_security_group_ids      = [aws_security_group.public-sg.id]
  iam_instance_profile        = aws_iam_instance_profile.worker_profile.name
  depends_on                  = [aws_subnet.private_subnets, aws_instance.master-instance]
  tags = {
    Name                                            = "worker_node-${each.key}"
    provision                                       = "terraform"
    "kubernetes.io/cluster/${var.k8s_cluster_name}" = "owned"
  }

  connection {
    type                = "ssh"
    host                = self.private_ip
    user                = "ec2-user"
    private_key         = data.aws_secretsmanager_secret_version.pem_key.secret_string
    bastion_user        = "ec2-user"
    bastion_private_key = data.aws_secretsmanager_secret_version.pem_key.secret_string
    bastion_host        = aws_instance.master-instance.public_ip
  }

  provisioner "file" {
    content     = data.aws_secretsmanager_secret_version.pem_key.secret_string
    destination = "/home/ec2-user/master.pem"
  }

  provisioner "file" {
    source      = "${path.module}/basic.sh"
    destination = "/home/ec2-user/basic.sh"
  }

  provisioner "file" {
    source      = "${path.module}/add_ip_san.sh"
    destination = "/home/ec2-user/add_ip_san.sh"
  }

  provisioner "file" {
    content = templatefile("${path.module}/kubeadm_worker_conf.tpl", {
      master_private_ip = aws_instance.master-instance.private_ip,
      hostname          = self.private_dns,
      node-ip           = self.private_ip
    })
    destination = "/home/ec2-user/kubeadm_join.conf"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/ec2-user/basic.sh",
      "sudo sh /home/ec2-user/basic.sh",
      "sudo yum install git -y",
      "chmod 400 /home/ec2-user/master.pem",

      "echo 'getting join command file from master'",
      "scp -o StrictHostKeyChecking=no -i /home/ec2-user/master.pem ec2-user@${aws_instance.master-instance.private_ip}:/home/ec2-user/kubeadm-join.out /home/ec2-user/kubeadm-join.out",

      "JOIN_COMMAND=$(cat /home/ec2-user/kubeadm-join.out)",
      "sed -i \"s/master_token/$(echo $JOIN_COMMAND | awk '{print $5}')/\" /home/ec2-user/kubeadm_join.conf",
      "sed -i \"s/cert_hashes/$(echo $JOIN_COMMAND | awk '{print $7}')/\" /home/ec2-user/kubeadm_join.conf",
      "sudo kubeadm join --config /home/ec2-user/kubeadm_join.conf",

      "echo 'getting the ca.crt and ca.key from master node' ",
      "mkdir -p /home/ec2-user/master_ca",
      "scp -o StrictHostKeyChecking=no -i /home/ec2-user/master.pem ec2-user@${aws_instance.master-instance.private_ip}:/etc/kubernetes/pki/ca.crt /home/ec2-user/master_ca/",

    # doing this because ca.key file requires root perssion but we don't have the root pem file , ec2-user pem cannot be used here.
      "ssh -o StrictHostKeyChecking=no -i /home/ec2-user/master.pem ec2-user@${aws_instance.master-instance.private_ip} \"sudo cat /etc/kubernetes/pki/ca.key\" > /home/ec2-user/master_ca/ca.key", 

      "echo 'generating new certificates with node ip and hostname sa SAN' ",
      "chmod +x /home/ec2-user/add_ip_san.sh",
      "sudo sh /home/ec2-user/add_ip_san.sh"
    ]
  }

}