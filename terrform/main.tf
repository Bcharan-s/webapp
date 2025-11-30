resource "aws_ecr_repository" "foo" {
  name                 = "foo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

locals {
  registry_url = aws_ecr_repository.foo.repository_url
  
}
resource "null_resource" "docker_image_build_and_push_to_ecr" {
    
    provisioner "local-exec" {
    
    interpreter = ["/bin/bash", "-c"]
    
    command    = <<EOF
        aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${local.registry_url}

        docker build -t myapp:latest -f ${path.module}/../website/Dockerfile ${path.module}/../website

        docker tag myapp:latest ${local.registry_url}:latest

        docker push ${local.registry_url}:latest
    EOF
    
  }
}

resource "aws_iam_role_policy" "test_policy" {
  name = "test_policy"
  role = aws_iam_role.test_role.id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
            "ecr:GetAuthorizationToken",

            "ecr:BatchCheckLayerAvailability",

            "ecr:GetDownloadUrlForLayer",

            "logs:CreateLogStream",

            "logs:PutLogEvents",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "test_role" {
  name = "test_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ecs-tasks.amazonaws.com",

        }
      },
    ]
  })
}

resource "aws_ecs_cluster" "foo" {
  name = "white-hart"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_task_definition" "service" {
  family = "service"
  container_definitions = jsonencode([
    {
      name      = "first"
      image     = "foo:latest"
      cpu       = 10
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }])
    
}

resource "aws_ecs_service" "mongo" {
  name            = "mongodb"
  cluster         = aws_ecs_cluster.foo.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 3
#   iam_role        = aws_iam_role.test_role.arn
#   depends_on      = [aws_iam_role_policy.test_policy]
#    load_balancer {
#     target_group_arn = aws_lb_target_group.foo.arn
#     container_name   = "first"
#     container_port   = 80
#   }
}

resource "aws_lb_target_group" "foo" {
  name     = "tf-example-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

