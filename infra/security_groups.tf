# ---------- Les 3 groupes de securite ----------
resource "aws_security_group" "alb" {
  #checkov:skip=CKV2_AWS_5:Attache a ALB cree dans la console (etape 8)
  name        = "${var.projet}-alb-sg"
  description = "ALB - HTTP public filtre par AWS WAF"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projet}-alb-sg" }
}

resource "aws_security_group" "app" {
  #checkov:skip=CKV2_AWS_5:Attache au service ECS cree dans la console (etape 8)
  name        = "${var.projet}-app-sg"
  description = "Conteneurs ECS - joignables uniquement depuis ALB"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projet}-app-sg" }
}

resource "aws_security_group" "db" {
  #checkov:skip=CKV2_AWS_5:Attache a la base RDS creee dans la console (etape 7)
  name        = "${var.projet}-db-sg"
  description = "RDS PostgreSQL - joignable uniquement depuis application"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${var.projet}-db-sg" }
}

# ---------- ALB ----------
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  #checkov:skip=CKV_AWS_260:Point entree public volontaire, filtre par AWS WAF (HTTPS impossible dans le Learner Lab)
  security_group_id = aws_security_group.alb.id
  description       = "HTTP public filtre par WAF"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "alb_vers_app" {
  security_group_id            = aws_security_group.alb.id
  description                  = "Vers les conteneurs sur le port 5000"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
}

# ---------- Application ----------
resource "aws_vpc_security_group_ingress_rule" "app_depuis_alb" {
  security_group_id            = aws_security_group.app.id
  description                  = "Port 5000 depuis ALB uniquement"
  referenced_security_group_id = aws_security_group.alb.id
  ip_protocol                  = "tcp"
  from_port                    = 5000
  to_port                      = 5000
}

resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS sortant via NAT (ECR, Secrets Manager, CloudWatch Logs)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
}

resource "aws_vpc_security_group_egress_rule" "app_vers_db" {
  security_group_id            = aws_security_group.app.id
  description                  = "PostgreSQL vers la base uniquement"
  referenced_security_group_id = aws_security_group.db.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# ---------- Base de donnees (aucune regle de sortie) ----------
resource "aws_vpc_security_group_ingress_rule" "db_depuis_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL depuis application uniquement"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}