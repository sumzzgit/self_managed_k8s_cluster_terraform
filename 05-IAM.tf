#--------------------- IAM ROLES CONFIGURATIONS -----------------------

// k8s master node instance profile role 

resource "aws_iam_role" "master_node_role" {
  name = "k8s_master_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "k8s_master_node_policy"

    policy = file("${path.module}/master_node_policy.json")

  }

  tags = {
    Name = "k8s_master_node_role"
  }

}

resource "aws_iam_role_policy_attachment" "master-cloudwatch-policy-attachement" {
  role       = aws_iam_role.master_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" // CloudWatchAgentServerPolicy
}

// instance profile for the master node 
resource "aws_iam_instance_profile" "master_profile" {
  name = "master_profile"
  role = aws_iam_role.master_node_role.name
}



// k8s worker node instance profile role 

resource "aws_iam_role" "worker_node_role" {
  name = "k8s_worker_node_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })

  inline_policy {
    name = "k8s_worker_node_policy"

    policy = file("${path.module}/worker_node_policy.json")
  }

  tags = {
    Name = "k8s_master_node_role"
  }

}

resource "aws_iam_role_policy_attachment" "worker-cloudwatch-policy-attachement" {
  role       = aws_iam_role.worker_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" // CloudWatchAgentServerPolicy
}

// instance profile for the worker node 
resource "aws_iam_instance_profile" "worker_profile" {
  name = "worker_profile"
  role = aws_iam_role.worker_node_role.name
}