terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── IAM role for EC2 (terminate itself) ───
resource "aws_iam_role" "malper_ec2" {
  name = "malper-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "malper_ec2_policy" {
  name = "malper-ec2-policy"
  role = aws_iam_role.malper_ec2.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ec2:TerminateInstances"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "malper_ec2" {
  name = "malper-ec2-profile"
  role = aws_iam_role.malper_ec2.name
}

# ─── IAM role for Lambda ───
resource "aws_iam_role" "malper_lambda" {
  name = "malper-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "malper_lambda_policy" {
  name = "malper-lambda-policy"
  role = aws_iam_role.malper_lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:DescribeInstances",
          "ec2:CreateTags",
          "ssm:StartSession",
          "iam:PassRole"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# ─── security group for EC2 ───
resource "aws_security_group" "malper_ec2" {
  name        = "malper-ec2-sg"
  description = "Malper scanner outbound only"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ─── Lambda ───
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "malper" {
  function_name    = "malper-launcher"
  role             = aws_iam_role.malper_lambda.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      AMI_ID           = var.ami_id
      SUBNET_ID        = var.subnet_id
      SG_ID            = aws_security_group.malper_ec2.id
      IAM_PROFILE      = aws_iam_instance_profile.malper_ec2.name
      SUPABASE_URL     = var.supabase_url
      SUPABASE_KEY     = var.supabase_key
      SUPABASE_BUCKET  = var.supabase_bucket
      OPENROUTER_API_KEY = var.openrouter_api_key
      SETUP_SCRIPT_URL   = var.setup_script_url
      API_KEY          = var.api_key
      TELEGRAM_BOT_TOKEN = var.telegram_bot_token
      TELEGRAM_CHAT_ID   = var.telegram_chat_id
    }
  }
}

# ─── API Gateway ───
resource "aws_apigatewayv2_api" "malper" {
  name          = "malper-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "malper" {
  api_id             = aws_apigatewayv2_api.malper.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.malper.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "malper" {
  api_id    = aws_apigatewayv2_api.malper.id
  route_key = "POST /scan"
  target    = "integrations/${aws_apigatewayv2_integration.malper.id}"
}

resource "aws_apigatewayv2_stage" "malper" {
  api_id      = aws_apigatewayv2_api.malper.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "malper" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.malper.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.malper.execution_arn}/*/*"
}

output "api_endpoint" {
  value = "${aws_apigatewayv2_stage.malper.invoke_url}/scan"
}

# ─── IAM user for dashboard ───
resource "aws_iam_user" "dashboard" {
  name = "watchdog-dashboard"
}

resource "aws_iam_user_policy" "dashboard_policy" {
  name = "watchdog-dashboard-policy"
  user = aws_iam_user.dashboard.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_access_key" "dashboard" {
  user = aws_iam_user.dashboard.name
}

output "dashboard_access_key_id" {
  value = aws_iam_access_key.dashboard.id
}

output "dashboard_secret_access_key" {
  value     = aws_iam_access_key.dashboard.secret
  sensitive = true
}
