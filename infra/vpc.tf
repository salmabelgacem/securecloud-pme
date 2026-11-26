locals {
  public_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
  app_cidrs    = ["10.0.11.0/24", "10.0.12.0/24"]
  data_cidrs   = ["10.0.21.0/24", "10.0.22.0/24"]
}

# ---------- VPC ----------
resource "aws_vpc" "main" {
  #checkov:skip=CKV2_AWS_11:Flow logs non actives - creation de role IAM interdite dans le Learner Lab
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.projet}-vpc" }
}

# Le groupe de securite par defaut est vide : il bloque tout
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.projet}-default-ferme" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.projet}-igw" }
}

# ---------- Sous-reseaux (3 couches x 2 zones) ----------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = var.zones[count.index]
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.projet}-public-${count.index + 1}" }
}

resource "aws_subnet" "app" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.app_cidrs[count.index]
  availability_zone = var.zones[count.index]
  tags              = { Name = "${var.projet}-app-${count.index + 1}" }
}

resource "aws_subnet" "data" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.data_cidrs[count.index]
  availability_zone = var.zones[count.index]
  tags              = { Name = "${var.projet}-data-${count.index + 1}" }
}

# ---------- Tables de routage ----------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.projet}-rt-public" }
}

resource "aws_route_table" "app" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.projet}-rt-app" }
}

# Aucune route vers Internet : la base reste isolee
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.projet}-rt-data" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  count          = 2
  subnet_id      = aws_subnet.app[count.index].id
  route_table_id = aws_route_table.app.id
}

resource "aws_route_table_association" "data" {
  count          = 2
  subnet_id      = aws_subnet.data[count.index].id
  route_table_id = aws_route_table.data.id
}

# ---------- NAT Gateway (creee seulement si enable_nat = true) ----------
resource "aws_eip" "nat" {
  count  = var.enable_nat ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${var.projet}-nat-eip" }
}

resource "aws_nat_gateway" "nat" {
  count         = var.enable_nat ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.projet}-nat" }
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route" "app_vers_nat" {
  count                  = var.enable_nat ? 1 : 0
  route_table_id         = aws_route_table.app.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat[0].id
}