##########################################################
# Variable Account Provider
### provider configuration is passed in from root module
##########################################################
provider "aws" {
  alias = "account"
}

provider "aws" {
  alias = "networking"
}
