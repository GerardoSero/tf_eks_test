# This data source is included for ease of sample architecture deployment
# and can be swapped out as necessary.
data "aws_availability_zones" "available" {}

resource "aws_vpc" "eks_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = map(
    "Name", "${var.cluster_name}-vpc",
    "Cluster", var.cluster_name,
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
  )
}

resource "aws_subnet" "eks_subnet" {
  count = 2

  availability_zone = data.aws_availability_zones.available.names[count.index]
  cidr_block        = cidrsubnet(aws_vpc.eks_vpc.cidr_block, 7, count.index)
  vpc_id            = aws_vpc.eks_vpc.id
  # Required in public subnets by EKS. https://aws.amazon.com/blogs/containers/upcoming-changes-to-ip-assignment-for-eks-managed-node-groups/
  map_public_ip_on_launch = true

  tags = map(
    "Name", "${var.cluster_name}-subnet-${data.aws_availability_zones.available.names[count.index]}",
    "Cluster", var.cluster_name,
    "kubernetes.io/cluster/${var.cluster_name}", "shared",
  )
}

resource "aws_internet_gateway" "eks_igw" {
  vpc_id = aws_vpc.eks_vpc.id

  tags = {
    Name    = "${var.cluster_name}-igw"
    Cluster = var.cluster_name
  }
}

resource "aws_route_table" "eks_rt" {
  vpc_id = aws_vpc.eks_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.eks_igw.id
  }

  tags = {
    Name    = "${var.cluster_name}-rt"
    Cluster = var.cluster_name
  }
}

resource "aws_route_table_association" "eks_rtassoc" {
  count = 2

  subnet_id      = aws_subnet.eks_subnet.*.id[count.index]
  route_table_id = aws_route_table.eks_rt.id
}