
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}




variable "apiGWname" {
  type    = string
  default = "test-for-acchot"

}




# Configure the AWS Provider
provider "aws" {
  region = "eu-west-1"
}


data "aws_api_gateway_rest_api" "my_rest_api" {
  name = var.apiGWname
}


## TO INTEGRATE THE 400 ERROR on 1 RESSOURCES, for 1 METHOD

resource "aws_api_gateway_model" "customError" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id

  name         = "customError"
  description  = "Custom error schema"
  content_type = "application/json"

  schema = jsonencode({
    type = "object",
    properties = {
      code = {
        type = "string"
      },
      message = {
        type = "string"
      },
      description = {
        type = "string"
      }
    }
  })
}

resource "aws_api_gateway_resource" "newResource" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  parent_id   = data.aws_api_gateway_rest_api.my_rest_api.root_resource_id
  path_part   = "viaterraform"
}

resource "aws_api_gateway_method" "newMethod" {
  rest_api_id   = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id   = aws_api_gateway_resource.newResource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "newIntegrationRequest" {
  rest_api_id             = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id             = aws_api_gateway_resource.newResource.id
  http_method             = aws_api_gateway_method.newMethod.http_method
  type                    = "HTTP"
  passthrough_behavior    = "WHEN_NO_MATCH"
  integration_http_method = "GET"
  uri                  = "https://httpbin.org/status/400"
  timeout_milliseconds = "29000"
  connection_type      = "INTERNET"
}


resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.newResource.id
  http_method = aws_api_gateway_method.newMethod.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "response_400" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.newResource.id
  http_method = aws_api_gateway_method.newMethod.http_method
  status_code = "400"
  response_models = {
    "application/json" = "customError"
  }
}


resource "aws_api_gateway_integration_response" "newIntegrationResponse_200" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.newResource.id
  http_method = aws_api_gateway_method.newMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
}

resource "aws_api_gateway_integration_response" "newIntegrationResponse_400" {
  selection_pattern = "400"
  rest_api_id       = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id       = aws_api_gateway_resource.newResource.id
  http_method       = aws_api_gateway_method.newMethod.http_method
  status_code       = aws_api_gateway_method_response.response_400.status_code
  response_templates = {
    "application/json" = <<EOF
{
  "code" = "400",
  "message" = "Bad Request",
  "description" = "The request was unacceptable, often due to missing a required parameter"
}
EOF
  }

}

## TO INTEGRATE THE DEFAULT 404

resource "aws_api_gateway_resource" "defaultResource" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  parent_id   = data.aws_api_gateway_rest_api.my_rest_api.root_resource_id
  path_part   = "{proxy+}"

}

resource "aws_api_gateway_method" "defaultMethod" {
  rest_api_id   = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id   = aws_api_gateway_resource.defaultResource.id
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "defaultRequestIntegration" {
  rest_api_id             = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id             = aws_api_gateway_resource.defaultResource.id
  http_method             = aws_api_gateway_method.defaultMethod.http_method
  type                    = "MOCK"
  timeout_milliseconds = 29000
  request_templates = {
    "application/json" = <<EOF
{
   "statusCode": 404
}
EOF
  }
}


resource "aws_api_gateway_method_response" "default_response_404" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.defaultResource.id
  http_method = aws_api_gateway_method.defaultMethod.http_method
  status_code = "404"
  response_models = {
    "application/json" = "customError"
  }
}


resource "aws_api_gateway_integration_response" "defaultReponseIntegration" {
  rest_api_id = data.aws_api_gateway_rest_api.my_rest_api.id
  resource_id = aws_api_gateway_resource.defaultResource.id
  http_method = aws_api_gateway_method.defaultMethod.http_method
  status_code = aws_api_gateway_method_response.default_response_404.status_code
  response_templates = {
    "application/json" = <<EOF
{
  "code" = "404",
  "message" = "NotFound",
  "description" = "The requested resource was not found"
}
EOF
  }
}
