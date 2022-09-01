locals {
  tags = {
    agent  = merge(var.tags, { "Name" = "${var.application}-agent" }),
    master = merge(var.tags, { "Name" = "${var.application}-master" })
  }
}