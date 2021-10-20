terraform {
  backend "s3" {
    bucket = "msel-ops-terraform-statefiles"
    # CHANGE THIS LINE BELOW FOR A NEW PROJECT
    key = "applications/derek-experiment-1" # CHANGE THIS!!!!
    # DID YOU READ ABOVE? STOP WHAT YOU ARE DOING AND DO IT NOW. CHANGE IT, CHANGE IT CHANGE IT!!!!
    region = "us-east-1"
    role_arn = "arn:aws:iam::005956675899:role/MselAdmins"
  }
}

locals {
  common_tags = {
    Project = "Experiment 1"
  }
  tags = merge(local.common_tags, var.tags)
}

module "tf_k8s_cluster" {
  # IF YOU CHANGE THIS, YOU MUST RUN 'terraform init'!!!
  source = "git::git@github.com:jhu-library-operations/tf-mod-aws-eks-k8s-cluster.git?ref=a7afa208b049fa6222b3d23f54cf4f4ac6f37fdf"
  cluster_name    = var.project_prefix
  tags            = local.tags
  network_id      = var.network_id
  private_subnets = var.private_subnets
  region          = var.region
  internal        = var.internal
  ssh_key_public  = var.ssh_key_public
  rg_name         = var.rg_name
  workers         = var.workers
  workers_min     = var.workers_min
  workers_max     = var.workers_max
  cluster_version = "1.20"

  instance_size = "t3.medium"

  # AWS: Used for cluster access after creation
  aws_role_arn = var.aws_role_arn

}

resource "helm_release" "test1" {
  count = length(var.namespaces)
  name = format("test-release-%s", var.namespaces[count.index])
  chart = "../experiment-1-helm"

  set {
    name = "Namespace"
    value = var.namespaces[count.index]
  }
}
  
data "aws_eks_cluster" "cluster" {
  name = var.project_prefix
  depends_on = [module.tf_k8s_cluster]
}

data "aws_eks_cluster_auth" "default" {
  name = var.project_prefix
  depends_on = [module.tf_k8s_cluster]
}

provider "aws" {
  region = var.region
  assume_role {
    role_arn = var.aws_role_arn
  }
}

provider "aws" {
  alias  = "mselops_admin"
  region = var.admin_region
  assume_role {
    role_arn = var.aws_admin_role_arn
  }
}

provider "helm" {
  kubernetes {
    host = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token = data.aws_eks_cluster_auth.default.token
  } 
}
