# ECR Repository to store the Docker image
resource "aws_ecr_repository" "countries_extraction" {
  name                 = "countries-extraction"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# S3 Bucket for storing the extracted data
resource "aws_s3_bucket" "countries_extraction" {
  bucket = var.s3_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

# S3 Bucket versioning
resource "aws_s3_bucket_versioning" "countries_extraction" {
  bucket = aws_s3_bucket.countries_extraction.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "countries_extraction" {
  bucket = aws_s3_bucket.countries_extraction.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# IAM role for the ECS task execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "countries_extraction_ecs_task_execution_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# IAM role for the ECS task (runtime)
resource "aws_iam_role" "ecs_task_role" {
  name = "countries_extraction_ecs_task_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the necessary policies to the ECS task execution role.
# The policy ARN is hard-coded because it's referencing an AWS-managed policy
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM policy for ECR access
resource "aws_iam_policy" "ecr_access" {
  name        = "countries_extraction_ecr_access"
  description = "Allow the task execution role to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:BatchCheckLayerAvailability"
      ]
      Resource = [aws_ecr_repository.countries_extraction.arn]
    }]
  })
}

# Attach the ECR access policy to the task execution role
resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecr_access.arn
}

# IAM policy for the task to access S3
resource "aws_iam_policy" "s3_access" {
  name        = "countries_extraction_s3_access"
  description = "Allow the countries extraction task to access S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Effect = "Allow"
        Resource = [
          aws_s3_bucket.countries_extraction.arn,
          "${aws_s3_bucket.countries_extraction.arn}/*",
        ]
      },
    ]
  })
}

# Attach the S3 access policy to the task role
resource "aws_iam_role_policy_attachment" "s3_access" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.s3_access.arn
}

# ECS Cluster
resource "aws_ecs_cluster" "countries_extraction" {
  name = "countries-extraction-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "countries_extraction" {
  family                   = "countries-extraction"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "countries-extraction"
      image     = "${aws_ecr_repository.countries_extraction.repository_url}:latest"
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.countries_extraction.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# CloudWatch Log Group for container logs
resource "aws_cloudwatch_log_group" "countries_extraction" {
  name              = "/ecs/countries-extraction"
  retention_in_days = 30
}

# VPC Configuration (assuming default VPC for simplicity)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group for the Fargate task
resource "aws_security_group" "countries_extraction" {
  name        = "countries-extraction-sg"
  description = "Allow outbound traffic for the countries extraction task"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# CloudWatch Event Rule for daily schedule at 1am UTC
resource "aws_cloudwatch_event_rule" "daily_extraction" {
  name                = "countries-extraction-daily"
  description         = "Trigger countries extraction daily at 1 AM"
  schedule_expression = "cron(0 1 * * ? *)" # 1 AM daily
}

# CloudWatch Event Target to run the ECS task
resource "aws_cloudwatch_event_target" "run_countries_extraction" {
  rule      = aws_cloudwatch_event_rule.daily_extraction.name
  target_id = "countries-extraction"
  arn       = aws_ecs_cluster.countries_extraction.arn
  role_arn  = aws_iam_role.cloudwatch_events_role.arn

  ecs_target {
    task_count          = 1
    task_definition_arn = aws_ecs_task_definition.countries_extraction.arn
    launch_type         = "FARGATE"

    network_configuration {
      subnets          = data.aws_subnets.default.ids
      security_groups  = [aws_security_group.countries_extraction.id]
      assign_public_ip = true
    }
  }
}

# IAM role for CloudWatch Events to run ECS tasks
resource "aws_iam_role" "cloudwatch_events_role" {
  name = "countries_extraction_cloudwatch_events_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      },
    ]
  })
}

# CloudWatch Events IAM Policy
resource "aws_iam_policy" "cloudwatch_events_policy" {
  name        = "countries_extraction_cloudwatch_events_policy"
  description = "Allow CloudWatch Events to run ECS tasks"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:RunTask"
        ]
        Resource = aws_ecs_task_definition.countries_extraction.arn
        Condition = {
          ArnEquals = {
            "ecs:cluster" = aws_ecs_cluster.countries_extraction.arn
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "iam:PassRole"
        ]
        Resource = [
          aws_iam_role.ecs_task_role.arn,
          aws_iam_role.ecs_task_execution_role.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:TagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_events_role_policy" {
  role       = aws_iam_role.cloudwatch_events_role.name
  policy_arn = aws_iam_policy.cloudwatch_events_policy.arn
}
