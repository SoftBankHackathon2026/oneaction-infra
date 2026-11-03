provider "aws" {
  profile             = var.aws_profile == "" ? null : var.aws_profile
  region              = var.aws_region
  allowed_account_ids = ["974402993422"]

  default_tags {
    tags = {
      Project = "oneaction"
      Owner   = var.owner
      Env     = "dev"
    }
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket         = "oneaction-tfstate-974402993422"
    key            = "dev/network/terraform.tfstate"
    region         = var.aws_region
    dynamodb_table = "oneaction-terraform-locks"
    encrypt        = true
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "oneaction-db-subnets"
  subnet_ids = data.terraform_remote_state.network.outputs.private_data_subnet_ids
  tags       = { Name = "oneaction-db-subnets" }
}

resource "aws_db_parameter_group" "postgres16" {
  name        = "oneaction-postgres16"
  family      = "postgres16"
  description = "oneaction PostgreSQL 16 parameters"

  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_cloudwatch_log_group" "postgresql" {
  name              = "/aws/rds/instance/oneaction-review-db/postgresql"
  retention_in_days = 7
  tags              = { Name = "oneaction-review-db-postgresql" }
}

resource "aws_db_instance" "review" {
  identifier = "oneaction-review-db"

  engine         = "postgres"
  engine_version = "16" # 메이저만 고정. auto_minor_version_upgrade 로 AWS 가 올린 마이너를 되돌리려 하지 않는다
  instance_class = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "oneaction_review"
  username = "oneaction_admin"

  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [data.terraform_remote_state.network.outputs.rds_security_group_id]
  parameter_group_name   = aws_db_parameter_group.postgres16.name
  publicly_accessible    = false
  multi_az               = false

  backup_retention_period   = var.backup_retention_period
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "oneaction-review-db-final"

  enabled_cloudwatch_logs_exports = ["postgresql"]
  auto_minor_version_upgrade      = true
  apply_immediately               = true

  tags = {
    Name             = "oneaction-review-db"
    created_by       = "rds-oss-skill"
    generation_model = "codex-gpt-5"
  }

  depends_on = [aws_cloudwatch_log_group.postgresql]
}
