output "dns_name" {
  value = aws_lb.main.dns_name
}

output "customer_vehicle_target_group_arn" {
  value = aws_lb_target_group.customer_vehicle.arn
}

output "work_order_target_group_arn" {
  value = aws_lb_target_group.work_order.arn
}

output "billing_target_group_arn" {
  value = aws_lb_target_group.billing.arn
}

output "execution_target_group_arn" {
  value = aws_lb_target_group.execution.arn
}

output "listener_arn" {
  value = aws_lb_listener.http.arn
}

output "security_group_id" {
  value = aws_security_group.alb.id
}

output "grafana_target_group_arn" {
  value = aws_lb_target_group.grafana.arn
}

output "alb_arn" {
  value = aws_lb.main.arn
}
