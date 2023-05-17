locals {
  tags = {
    agent    = merge(var.tags, { "Name" = "${var.application}-agent" }),
    agent_db = merge(var.tags, { "Name" = "${var.application}-agent-db" }),
    us_agent = merge(var.tags, { "Name" = "${var.us_application}-agent" }),
    master   = merge(var.tags, { "Name" = "${var.application}-master" })
  }
}