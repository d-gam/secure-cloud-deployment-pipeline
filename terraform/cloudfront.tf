locals {
  api_gateway_domain = replace(
    replace(aws_apigatewayv2_api.todo_api.api_endpoint, "https://", ""),
    "/",
    ""
  )
}

resource "aws_cloudfront_response_headers_policy" "security_headers" {
  name = "${var.project_name}-security-headers-${var.environment}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000
      include_subdomains         = true
      override                   = true
    }

    content_type_options {
      override = true
    }
  }

  custom_headers_config {
    items {
      header   = "Cross-Origin-Resource-Policy"
      value    = "cross-origin"
      override = true
    }
  }
}

resource "aws_cloudfront_distribution" "api_distribution" {
  enabled     = true
  comment     = "secure-cloud-pipeline CDN in front of API Gateway, adds security headers to all responses"
  price_class = "PriceClass_100"

  origin {
    domain_name = local.api_gateway_domain
    origin_id   = "api-gateway-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods           = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods             = ["GET", "HEAD"]
    target_origin_id           = "api-gateway-origin"
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security_headers.id

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type"]
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
