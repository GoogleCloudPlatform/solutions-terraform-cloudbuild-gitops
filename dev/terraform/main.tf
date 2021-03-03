module "create_vpc_network" {
  source = "./modules/network"
  vpc_network_name = var.vpc_network_name
}
