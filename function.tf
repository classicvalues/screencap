data "aws_region" "current" {}

resource "aws_iam_role" "screencap_role" {
  name = var.name

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "log_perms" {
  name = "log_perms"
  role = aws_iam_role.screencap_role.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

locals {
  source_path = "${path.module}/src"
}

resource "null_resource" "zip" {
  triggers = {
    index_js     = filebase64sha256("${local.source_path}/index.js")
    package_json = filebase64sha256("${local.source_path}/package.json")
    package_lock = filebase64sha256("${local.source_path}/package-lock.json")
  }

  provisioner "local-exec" {
    command = "cd ${local.source_path} && npm install --production"
  }
}

data "archive_file" "package_zip" {
  type = "zip"
  source_dir  = "${local.source_path}"
  output_path = "${path.module}/${var.name}-${null_resource.zip.id}.zip"
}

resource "aws_lambda_function" "lambda" {
  filename      = data.archive_file.package_zip.output_path
  function_name = var.name
  handler       = "index.handler"
  role          = aws_iam_role.screencap_role.arn
  runtime       = "nodejs12.x"
  timeout       = 60
  memory_size   = 3008

  source_code_hash = filebase64sha256(data.archive_file.package_zip.output_path)

  tags = var.tags
}

resource "aws_lambda_permission" "gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.arn
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}
