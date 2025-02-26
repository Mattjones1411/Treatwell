# ========================
# IAM Role for ECS Task Execution
# ========================
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy_attachment" "ecs_task_execution_attach" {
  name       = "ecs-task-execution-attach"
  roles      = [aws_iam_role.ecs_task_execution_role.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ========================
# ECS Cluster
# ========================
resource "aws_ecs_cluster" "data_extract_cluster" {
  name = "country-extraction-cluster"
}

# ========================
# ECS Task Definition
# ========================
resource "aws_ecs_task_definition" "data_extract_task" {
  family                   = "country-extraction-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "country-extraction-container"
      image     = "${var.aws_account_id}.dkr.ecr.eu-west-1.amazonaws.com/country-extraction-job:latest"
      essential = true
      command   = ["poetry", "country-extraction.py"]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/country-extraction-logs"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# ========================
# CloudWatch Log Group for ECS Task
# ========================
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "/ecs/country-extraction-logs"
  retention_in_days = 7
}

# ========================
# EventBridge Rule for Scheduled Execution
# ========================
resource "aws_cloudwatch_event_rule" "ecs_scheduled_rule" {
  name                = "country-extraction-daily-task"
  schedule_expression = "cron(0 1 * * ? *)" # Runs at 1 AM UTC daily
}

resource "aws_cloudwatch_event_target" "ecs_target" {
  rule      = aws_cloudwatch_event_rule.ecs_scheduled_rule.name
  arn       = aws_ecs_cluster.data_extract_cluster.arn
  role_arn  = aws_iam_role.ecs_task_execution_role.arn
  ecs_target {
    task_definition_arn = aws_ecs_task_definition.data_extract_task.arn
    task_count          = 1
    launch_type         = "FARGATE"
    network_configuration {
      subnets          = ["subnet-xxxxxxx"] # Replace with your actual subnet IDs
      security_groups  = ["sg-xxxxxxx"] # Replace with actual security group ID
      assign_public_ip = true
    }
  }
}

# ========================
# IAM Role for EventBridge to Trigger ECS Task
# ========================
resource "aws_iam_role" "eventbridge_invoke_ecs_role" {
  name = "eventbridgeInvokeEcsRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "eventbridge_ecs_policy" {
  name        = "eventbridge-ecs-policy"
  description = "Allows EventBridge to start ECS tasks"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "ecs:RunTask"
      Resource = aws_ecs_task_definition.data_extract_task.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eventbridge_ecs_attach" {
  role       = aws_iam_role.eventbridge_invoke_ecs_role.name
  policy_arn = aws_iam_policy.eventbridge_ecs_policy.arn
}

