# self_managed_k8s_cluster_terraform
This repo contains the terraform code create k8s cluster in ec2 instances using kubeadm

After applying this terraform code resource created are :
VPC 
Internte Gateway 
Two public and private subntes 
NAT instance ( AMI is hardcoded for NAT instance for ap-south-1 region ) -> search for "vpc nat" for AMI ID for respective region .
one master ec2 instance in public subnet 
two worker ec2 instances in private subnets ( change the number accordingly )
master IAM role for master node 
worker IAM role worker nodes

Note -> all these are done in ap-south-1 region (mumbai)
