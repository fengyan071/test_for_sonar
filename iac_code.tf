terraform {
  backend "oss" {
   encrypt    = true
  }
}

provider "kubernetes" {
  host                   = local.k8s_api_server_fqdn_w_port
  client_certificate     = module.ali_k8s.client_cert
  insecure               = true
  client_key             = module.ali_k8s.client_key
}

provider "helm" {
  kubernetes {
    host                   = local.k8s_api_server_fqdn_w_port
    client_certificate     = module.ali_k8s.client_cert
    insecure               = true
    client_key             = module.ali_k8s.client_key
  }
}


resource "alicloud_db_connection" "public_endpoint" {
  count             = var.appResourceConfig.ali_sqlserver.public ? 1 : 0
  instance_id       = module.ali_sqlserver.id
  connection_prefix = local.db_ali_prefix
  port              = 1433
}

# K8s API access control list
module "slb-acl-k8s-api" {
  password = "123"
  source            = "../terraform-modules/modules/ali_acl"
  name_prefix       = "${var.project_name}-${local.env}-api-k8s-slb"
  entry_list        = local.acl_slb_int_k8s
  new_naming_convention = var.new_naming_convention
  tags = local.tags
}


# K8s API access control list
resource "null_resource" "acl_slb_k8s_api" {
  depends_on = [ module.slb-acl-k8s-api ]
  triggers = {
    slb_id   = data.alicloud_slbs.taggedInstances.ids[0]
    acl_id   = module.slb-acl-k8s-api.this_acl_id
  }
  provisioner "local-exec" {
    command = "bash ${path.module}/scripts/manage-k8s-api-slb-acl.sh bind ${self.triggers.slb_id} ${self.triggers.acl_id}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/scripts/manage-k8s-api-slb-acl.sh unbind ${self.triggers.slb_id} ${self.triggers.acl_id}"
  }
}


############################################# NETWORKING #####################################
module "ali_vpc" {
  source            = "../terraform-modules/modules/ali_vpc"
  name              = local.generic_name
  network           = var.vpcRange
  eip_bandwidth     = var.eip_bandwidth
  resource_group_id = var.ali.resource_group_id
  new_naming_convention = var.new_naming_convention
  nat_vswitch = {
    zone   = var.zones.natGateway
    subnet = local.nat_gateway_subnet
  }
  utility_vswitch = {
    enabled = true
    subnet  = local.utility_subnet
    zone    = var.zones.utility
  }
  tags = local.tags
}

module "ali_cen" {
  depends_on      = [module.ali_vpc]
  count           = length(var.cens)
  source          = "../terraform-modules/modules/ali_cen"
  region          = lookup(var.cens[count.index], "region")
  project_name    = var.project_name
  env             = var.env
  purpose         = lookup(var.cens[count.index], "connect_system")
  enable_routing  = lookup(var.cens[count.index], "enable_routing")
  entry_list = lookup(var.cens[count.index], "entry_list")
  new_naming_convention = var.new_naming_convention

  tags = local.tags
}

##############################################################################################

############################################# DKMS ###########################################

resource "alicloud_vswitch" "kms_vswitch" {
  count             = length(local.kms_zone) == 0 ? 0 : 1
  name              = "kms-${var.project_name}-${local.env}-${local.kms_zone[0]}"
  availability_zone = local.kms_zone[0]
  cidr_block        = local.kms_subnet
  vpc_id            = module.ali_vpc.id
  tags = merge(
    var.tags,
    {
      "Name"        ="kms-${var.project_name}-${local.env}-${local.kms_zone[0]}"
    }
  )
}

resource "alicloud_kms_instance" "kms_instance" {
  depends_on      = [module.ali_vpc]
  product_version = "3"
  vpc_id          = module.ali_vpc.id
  zone_ids        = local.kms_zone
  vswitch_ids     = length(local.kms_zone) == 0 ? [] : split("," , alicloud_vswitch.kms_vswitch[0].id)
  vpc_num         = var.dmks_instance.vpc_num
  key_num         = var.dmks_instance.key_num
  secret_num      = var.dmks_instance.secret_num
  spec            = var.dmks_instance.spec
  timeouts {
    create = "300m"
  }
}

##############################################################################################


