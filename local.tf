locals {
  ############################################# COMMON VARIABLES ########################################

  env                                 = "${var.env}${var.pull_request_id}"
  is_dr_env                           = var.logical_environment == "dr" ? true : false
  generic_name                        = var.env == "dev" ? "${var.project_name}-iac-${local.env}-${data.alicloud_regions.current.regions[0].id}" : "${var.project_name}-${local.env}-${data.alicloud_regions.current.regions[0].id}"

  infra_cr_url_base                   = "${var.crUrlBase}"
  infra_cr_url                        = "${local.infra_cr_url_base}/iac"

  db_env_postfix                      = try(var.appResourceConfig.ali_sqlserver.db_env_postfix, "")
  db_ali_prefix                       = "${var.project_name}${var.pull_request_id}-db${local.db_env_postfix}"
  db_dns_prefix                       = "${local.db_ali_prefix}.mgmt"

  k8s_env_postfix                     = try(var.k8s.k8s_env_postfix, "")
  k8s_ali_prefix                      = "master${var.pull_request_id}${local.k8s_env_postfix}"
  k8s_dns_prefix                      = "${local.k8s_ali_prefix}.mgmt"
  k8s_api_server_fqdn                 = "${local.k8s_dns_prefix}.${var.cloudflare.zone}"
  k8s_api_server_fqdn_w_port          = "${local.k8s_api_server_fqdn}:6443"
  k8s_api_server_fqdn_w_port_w_prot   = "https://${local.k8s_api_server_fqdn_w_port}"

  tags =  merge(var.tags, {
      "APMID"            = "POLICYONE"
      "ResourceGroup"    = "POLICYONE-${upper(var.env)}-RG"
      "DataPII"          = "false"
  })
