provider "aws" {
  region = "eu-west-1"
}
provider "aws" {
  alias = "virgina"
  region = "us-east-1"
}