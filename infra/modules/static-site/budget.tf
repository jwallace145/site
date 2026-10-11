# -----------------------------------------------------------------------------
# billing: monthly cost alert.
# -----------------------------------------------------------------------------

resource "aws_budgets_budget" "billing_monthly" {
  name         = local.names.billing_monthly
  budget_type  = "COST"
  limit_amount = tostring(var.billing.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.billing.alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.billing.alert_email]
  }

  tags = merge(var.tags, { Name = local.names.billing_monthly })
}
