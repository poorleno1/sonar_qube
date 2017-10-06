########################## Variables ###########################
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {
    default = "jarekole"
}

########################## Provider ###########################
provider "aws" {

    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "eu-west-1"
}

########################## Resources  ###########################
resource "aws_instance" "sonar_qube1" {
    ami = "ami-785db401"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    subnet_id = "subnet-ddb622aa"
    associate_public_ip_address = "true"

    connection {
        user = "ec2_user"
       private_key = "${file(var.private_key_path)}"
#       private_key = "${file(/Users/jarekole/jarekole.pem)}"
    }
}


#resource "aws_default_vpc" "default" {
#        tags {
#                    Name = "vpc-938535f6"
#                        }
#}

########################## Output ###########################

output "aws_instance_public_dns_name" {
      value = "${aws_instance.sonar_qube1.public_dns}"
}
