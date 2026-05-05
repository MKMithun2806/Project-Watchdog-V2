variable "aws_region"        { default = "ap-south-2" }
variable "ami_id"            {}  # Ubuntu 24.04 x86 in your region
variable "subnet_id"         {}  # default VPC subnet
variable "supabase_url"      {}
variable "supabase_key"      { sensitive = true }
variable "supabase_bucket"   { default = "recon-reports" }
variable "openrouter_api_key" { sensitive = true }
variable "setup_script_url"  {}  # GitHub raw URL for setup.sh
