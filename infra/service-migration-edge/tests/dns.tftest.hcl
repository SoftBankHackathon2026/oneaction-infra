mock_provider "aws" {}

run "no_record_before_alb_exists" {
  command = plan
  assert {
    condition     = length(aws_route53_record.receipt) == 0
    error_message = "Do not send traffic to an unprovisioned endpoint."
  }
}

run "one_fixed_cloud_receipt" {
  command = plan
  variables {
    aws_alb_dns_name = "ghost-service-migration-123.ap-northeast-2.elb.amazonaws.com"
  }
  assert {
    condition     = aws_route53_record.receipt[0].name == "service-migration.hackerthon.yubin.dev" && aws_route53_record.receipt[0].type == "CNAME" && length(aws_route53_record.receipt[0].records) == 1
    error_message = "Receipt DNS must name one AWS ALB, never both onprem and cloud writers."
  }
}

run "url_rejected" {
  command = plan
  variables {
    aws_alb_dns_name = "https://ghost-service-migration-123.ap-northeast-2.elb.amazonaws.com"
  }
  expect_failures = [var.aws_alb_dns_name]
}
