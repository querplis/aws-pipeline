#dns name of lb
output "lb_dns_name" {
  value =  module.lb.lb.dns_name
}
