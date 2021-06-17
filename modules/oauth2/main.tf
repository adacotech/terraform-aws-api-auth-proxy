data "aws_iam_policy_document" "assume_role_policy_lambda" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "assume_role_policy_authorizer" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "role_policy_lambda" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:DeleteItem"
    ]
    resources = [aws_dynamodb_table.authorize.arn]
  }
}

data "aws_iam_policy_document" "role_policy_authorizer" {
  statement {
    effect = "Allow"
    actions = [
      "lambda:InvokeFunction",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "${var.unique_name}-lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_lambda.json
}

resource "aws_iam_role_policy" "role_policy_lambda" {
  name   = "${var.unique_name}-role-policy-lambda"
  policy = data.aws_iam_policy_document.role_policy_lambda.json
  role   = aws_iam_role.iam_for_lambda.id
}

resource "aws_iam_role" "iam_for_authorizer" {
  name               = "${var.unique_name}-authorizer"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy_authorizer.json
}

resource "aws_iam_role_policy" "role_policy_authorizer" {
  name   = "${var.unique_name}-role-policy-authorizer"
  policy = data.aws_iam_policy_document.role_policy_authorizer.json
  role   = aws_iam_role.iam_for_authorizer.id
}


/* oauth2 authorizer */
resource "aws_apigatewayv2_authorizer" "oauth2" {
  api_id                            = var.api_id
  authorizer_type                   = "REQUEST"
  authorizer_credentials_arn        = aws_iam_role.iam_for_authorizer.arn
  authorizer_uri                    = aws_lambda_function.authorizer.invoke_arn
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  authorizer_result_ttl_in_seconds  = 0
  identity_sources                  = []
  name                              = "${var.unique_name}-authorizer"
}

resource "null_resource" "authorize_build" {
  triggers = {
    src         = filesha256("${path.module}/lambda/authorizer/function.py")
    docker_file = filesha256("${path.module}/lambda/Dockerfile")
    script      = filesha256("${path.module}/lambda/build.sh")
    dependency  = filesha256("${path.module}/lambda/authorizer/requirements.txt")
  }
  provisioner "local-exec" {
    command = "${path.module}/lambda/build.sh api-auth-authorizer ${path.module}/lambda/authorizer ${abspath(path.module)}/lambda"
  }
}

resource "null_resource" "signin_build" {
  triggers = {
    src         = filesha256("${path.module}/lambda/signin/function.py")
    docker_file = filesha256("${path.module}/lambda/Dockerfile")
    script      = filesha256("${path.module}/lambda/build.sh")
    dependency  = filesha256("${path.module}/lambda/signin/requirements.txt")
  }
  provisioner "local-exec" {
    command = "${path.module}/lambda/build.sh api-auth-signin ${path.module}/lambda/signin ${abspath(path.module)}/lambda"
  }
}

resource "null_resource" "callback_build" {
  triggers = {
    src         = filesha256("${path.module}/lambda/callback/function.py")
    docker_file = filesha256("${path.module}/lambda/Dockerfile")
    script      = filesha256("${path.module}/lambda/build.sh")
    dependency  = filesha256("${path.module}/lambda/callback/requirements.txt")
  }
  provisioner "local-exec" {
    command = "${path.module}/lambda/build.sh api-auth-callback ${path.module}/lambda/callback ${abspath(path.module)}/lambda"
  }
}

data "archive_file" "authorizer" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dst/api-auth-authorizer"
  output_path = "${path.module}/authorizer.zip"
  depends_on = [
    null_resource.authorize_build
  ]
}

data "archive_file" "signin" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dst/api-auth-signin"
  output_path = "${path.module}/signin.zip"
  depends_on = [
    null_resource.signin_build
  ]
}

data "archive_file" "callback" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/dst/api-auth-callback"
  output_path = "${path.module}/callback.zip"
  depends_on = [
    null_resource.callback_build
  ]
}


/* lambda function */
resource "aws_lambda_function" "authorizer" {
  filename         = data.archive_file.authorizer.output_path
  function_name    = "${var.unique_name}-authorizer"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.authorizer.output_base64sha256
  environment {
    variables = {
      OAUTH2_ISSUER       = var.oauth2_issuer
      OAUTH2_SCOPE        = var.oauth2_scope
      OAUTH2_AUDIENCE     = var.oauth2_audience
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.authorize.name
      COOKIE_TOKEN_KEY    = local.cookie_token_key
    }
  }
}

resource "aws_lambda_function" "signin" {
  filename         = data.archive_file.signin.output_path
  function_name    = "${var.unique_name}-authorize-signin"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.signin.output_base64sha256
  environment {
    variables = {
      OAUTH2_ISSUER                 = var.oauth2_issuer
      OAUTH2_SCOPE                  = var.oauth2_scope
      OAUTH2_AUDIENCE               = var.oauth2_audience
      OAUTH2_CLIENT_ID              = var.oauth2_client_id
      OAUTH2_AUTHORIZATION_ENDPOINT = local.oauth2_authorization_endpoint
      DYNAMODB_TABLE_NAME           = aws_dynamodb_table.authorize.name
      REDIRECT_URI                  = "${var.base_uri}/api_authorize/callback"
      COOKIE_FEDERATION_KEY         = local.cookie_federation_key
    }
  }
}

resource "aws_lambda_function" "callback" {
  filename         = data.archive_file.callback.output_path
  function_name    = "${var.unique_name}-authorize-callback"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "function.lambda_handler"
  runtime          = "python3.8"
  source_code_hash = data.archive_file.callback.output_base64sha256
  environment {
    variables = {
      OAUTH2_ISSUER         = var.oauth2_issuer
      OAUTH2_SCOPE          = var.oauth2_scope
      OAUTH2_CLIENT_ID      = var.oauth2_client_id
      OAUTH2_TOKEN_ENDPOINT = local.oauth2_token_endpoint
      DYNAMODB_TABLE_NAME   = aws_dynamodb_table.authorize.name
      REDIRECT_URI          = "${var.base_uri}/api_authorize/callback"
      COOKIE_TOKEN_KEY      = local.cookie_token_key
      COOKIE_FEDERATION_KEY = local.cookie_federation_key
    }
  }
}

/* oauth2 request startpoint */
resource "aws_apigatewayv2_route" "signin" {
  api_id             = var.api_id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.signin.id}"
  route_key          = "GET /api_authorize/signin"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_route" "callback" {
  api_id             = var.api_id
  operation_name     = "ConnectRoute"
  target             = "integrations/${aws_apigatewayv2_integration.callback.id}"
  route_key          = "GET /api_authorize/callback"
  authorization_type = "NONE"
}

resource "aws_apigatewayv2_integration" "signin" {
  api_id                 = var.api_id
  integration_type       = "AWS_PROXY"
  credentials_arn        = aws_iam_role.iam_for_authorizer.arn
  connection_type        = "INTERNET"
  description            = "Authorization startpoint"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.signin.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "callback" {
  api_id                 = var.api_id
  integration_type       = "AWS_PROXY"
  credentials_arn        = aws_iam_role.iam_for_authorizer.arn
  connection_type        = "INTERNET"
  description            = "Authorization callback"
  integration_method     = "POST"
  integration_uri        = aws_lambda_function.callback.invoke_arn
  payload_format_version = "2.0"
}


/* dynamodb */
resource "aws_dynamodb_table" "authorize" {
  name         = "${var.unique_name}-authorize"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"

  attribute {
    name = "pk"
    type = "S"
  }

  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
}
