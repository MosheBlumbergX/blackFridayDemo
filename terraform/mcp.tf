# The MCP server the Flink agent calls: one Lambda behind a Function URL.
# The bearer token is generated here, passed to the Flink connection, and never
# leaves Terraform state and the Lambda environment.

resource "random_password" "mcp_token" {
  length  = 48
  special = false
}

data "archive_file" "mcp" {
  type        = "zip"
  source_file = "${path.module}/../lambda/mcp_server.py"
  output_path = "${path.module}/../lambda/build/mcp_server.zip"
}

resource "aws_ses_email_identity" "notify" {
  email = var.notify_email
}

resource "aws_iam_role" "mcp" {
  name = "${var.project}-mcp"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "mcp" {
  name = "${var.project}-mcp"
  role = aws_iam_role.mcp.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.mcp.arn}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = aws_ses_email_identity.notify.arn
      }
    ]
  })
}

resource "aws_cloudwatch_log_group" "mcp" {
  name              = "/aws/lambda/${var.project}-mcp"
  retention_in_days = 7
  tags              = local.tags
}

resource "aws_lambda_function" "mcp" {
  function_name    = "${var.project}-mcp"
  role             = aws_iam_role.mcp.arn
  runtime          = "python3.12"
  handler          = "mcp_server.handler"
  filename         = data.archive_file.mcp.output_path
  source_code_hash = data.archive_file.mcp.output_base64sha256
  timeout          = 30
  memory_size      = 256

  environment {
    variables = {
      MCP_TOKEN         = random_password.mcp_token.result
      PRICE_API_KEY     = var.price_api_key
      SES_SENDER        = var.notify_email
      ALLOWED_RECIPIENT = var.notify_email
    }
  }

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.mcp.name
  }

  tags = local.tags

  depends_on = [aws_iam_role_policy.mcp]
}

# Authorisation is the bearer token checked inside the function, because Flink
# sends a static Authorization header and cannot sign requests with IAM.
resource "aws_lambda_function_url" "mcp" {
  function_name      = aws_lambda_function.mcp.function_name
  authorization_type = "NONE"
}

# The provider adds lambda:InvokeFunctionUrl itself when it creates a public URL.
# Recent AWS behaviour also needs lambda:InvokeFunction, added after the URL exists
# so the two updates cannot collide (ResourceConflictException).

resource "aws_lambda_permission" "url_invoke" {
  statement_id             = "AllowPublicInvokeFunction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.mcp.function_name
  principal                = "*"
  invoked_via_function_url = true

  depends_on = [aws_lambda_function_url.mcp]
}
