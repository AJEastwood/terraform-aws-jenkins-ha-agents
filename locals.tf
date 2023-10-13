locals {
  tags = {
    agent    = merge(var.tags, { "Name" = "${var.application}-agent" }),
    agent_db = merge(var.tags, { "Name" = "${var.application}-agent-db" }),
    master   = merge(var.tags, { "Name" = "${var.application}-master" })
  }
}