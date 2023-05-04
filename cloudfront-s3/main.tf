resource "aws_s3_bucket" "website_bucket" {
    bucket = "s3-static-website-bucket-test"

    tags = {
        Name = "s3-static-website"
        Environment = "test"
    }

    lifecycle {
        prevent_destroy = false
    }
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.website_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.example]
  bucket = aws_s3_bucket.website_bucket.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "server_test_encryption" {
  bucket = aws_s3_bucket.website_bucket.id
    rule {
      apply_server_side_encryption_by_default {
        # kms_master_key_id = aws_kms_key.mykey.arn
        sse_algorithm     = "AES256"
      }
    }
  }

resource "aws_s3_object" "files" {
  for_each = fileset("/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/", "*")
  bucket                 = aws_s3_bucket.website_bucket.id
  key    = each.value
  source = "/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/${each.value}"
  etag   = filemd5("/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/${each.value}")
  server_side_encryption = "AES256"
  content_type = "text/html"
}

# # resource "aws_s3_object" "file" {
# #   for_each = fileset("/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/", "*")

# #   bucket       = aws_s3_bucket.website_bucket.id
# #   key          = each.value
# #   source       = "/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/${each.value}"
# #   source_hash  = filemd5("/Users/sathyaraj.durai/src/Talent-Academy/cloudfront-s3/s3_file/${each.value}")
# #   #acl          = "public-read"
# #   # added:
# #   content_type = "text/html"
# }
resource "aws_s3_bucket_public_access_block" "test_bucket" {
  bucket = aws_s3_bucket.website_bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "my_bucket" {
    bucket = aws_s3_bucket.website_bucket.id
    
    versioning_configuration {
      status = "Enabled"
    }
  
}

resource "aws_s3_bucket_policy" "access_to_public" {
  depends_on = [
    aws_cloudfront_origin_access_control.cf_oac
  ]
  bucket = aws_s3_bucket.website_bucket.id
  
  policy = data.aws_iam_policy_document.allow_access_to_public.json
}
data "aws_iam_policy_document" "allow_access_to_public" {
  statement {
    principals {
      type = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    actions = [
      "s3:*"
    ]

    resources = [
      #aws_s3_bucket.website_bucket.arn/,
      "${aws_s3_bucket.website_bucket.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceARN"
      values = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}
resource "aws_s3_bucket_website_configuration" "static_site" {
  bucket = aws_s3_bucket.website_bucket.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.website_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.cf_oac.id
    origin_id                = aws_s3_bucket.website_bucket.id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Some comment"
  default_root_object = "index.html"

  aliases = ["website.sathyaraj.aws.crlabs.cloud"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.website_bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
  
  viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  
  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "IN"]
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    acm_certificate_arn = aws_acm_certificate.cf_cert.arn
    ssl_support_method  = "sni-only"
  }
}


resource "aws_cloudfront_origin_access_control" "cf_oac" {
  name                              = "s3_test"
  description                       = "control setting Policy"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_acm_certificate" "cf_cert" {
  domain_name       = "website.sathyaraj.aws.crlabs.cloud"
  validation_method = "DNS"

  tags = {
    Environment = "cfcdtest"
  }

  provider = aws.virgina

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_route53_zone" "myzone" {
  name         = "sathyaraj.aws.crlabs.cloud"
}

resource "aws_route53_record" "cf_validate" {
  for_each = {
    for dvo in aws_acm_certificate.cf_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.myzone.zone_id
}

# resource "aws_acm_certificate_validation" "usregion" {
#   certificate_arn         = aws_acm_certificate.cf_cert.arn
#   validation_record_fqdns = [for record in aws_route53_record.cf_validate : record.fqdn]
# }

resource "aws_route53_record" "aliascf" {
  zone_id = data.aws_route53_zone.myzone.zone_id
  name    = "website.sathyaraj.aws.crlabs.cloud"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = true
  }
}