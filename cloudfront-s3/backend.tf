terraform {
    backend "s3" {
        bucket = "talent-academy-sathyaraj-lab-tfstates1"
        key = "talent-academy/cloudfront-s3/terraform.tfstates"
        dynamodb_table = "terraform-lock"
    }
}