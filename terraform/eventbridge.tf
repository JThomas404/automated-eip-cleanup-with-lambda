resource "aws_cloudwatch_event_rule" "boto3_eip_cw_rule" {
  name                = "daily-eip-cleanup-rule"
  description         = "Triggers the Elastic IP Cleanup Lambda daily"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "boto3_eip_cw_target" {
  rule      = aws_cloudwatch_event_rule.boto3_eip_cw_rule.name
  target_id = "eip-cleanup-target"
  arn       = aws_lambda_function.ElasticIPCleanupLambda.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ElasticIPCleanupLambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.boto3_eip_cw_rule.arn
}
