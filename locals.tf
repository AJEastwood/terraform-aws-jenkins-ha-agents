locals {
  tags = {
    agent    = merge(var.tags, { "Name" = "${var.application}-agent" }),
    agent_db = merge(var.tags, { "Name" = "${var.application}-agent-db" }),
    agent_qa = merge(var.tags, { "Name" = "${var.application}-agent-qa" }),
    us_agent = merge(var.tags, { "Name" = "${var.us_application}-agent" }),
    master   = merge(var.tags, { "Name" = "${var.application}-master" })
  }
}