########################## Variables ###########################
variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "private_key_path" {}
variable "key_name" {
    default = "jarekole"
}

variable "network_address_space" {
    default = "10.1.0.0/16"
}

variable "subnet1_address_space" {
    default = "10.1.0.0/24"
}

variable "subnet2_address_space" {
    default = "10.1.1.0/24"
}
########################## Provider ###########################
provider "aws" {

    access_key = "${var.aws_access_key}"
    secret_key = "${var.aws_secret_key}"
    region = "eu-west-1"
}

########################## Data ###########################
data "aws_availability_zones" "available" {}


########################## Networking ###########################
resource "aws_vpc" "sonar_vpc" {
    cidr_block = "${var.network_address_space}"
    enable_dns_hostnames = "true"
}

resource "aws_internet_gateway" "igw" {
    vpc_id = "${aws_vpc.sonar_vpc.id}"
}

resource "aws_subnet" "subnet1" {
    cidr_block = "${var.subnet1_address_space}"
    vpc_id = "${aws_vpc.sonar_vpc.id}"
    map_public_ip_on_launch = "true"
    availability_zone = "${data.aws_availability_zones.available.names[0]}"
}

resource "aws_subnet" "subnet2" {
    cidr_block = "${var.subnet2_address_space}"
    vpc_id = "${aws_vpc.sonar_vpc.id}"
    map_public_ip_on_launch = "true"
    availability_zone = "${data.aws_availability_zones.available.names[1]}"
}


########################## Routing ###########################
resource "aws_route_table" "rtb" {
    vpc_id = "${aws_vpc.sonar_vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.igw.id}"
    }
}

resource "aws_route_table_association" "rta-subnet1" {
    subnet_id = "${aws_subnet.subnet1.id}"
    route_table_id = "${aws_route_table.rtb.id}"
}

resource "aws_route_table_association" "rta-subnet2" {
    subnet_id = "${aws_subnet.subnet2.id}"
    route_table_id = "${aws_route_table.rtb.id}"
}

########################## Security groups  ###########################
resource "aws_security_group" "elb-sg" {
    name = "sonar_elb_sg"
    vpc_id = "${aws_vpc.sonar_vpc.id}"

    #HTTP from anywhere
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

resource "aws_security_group" "sonar" {
    name = "sonar"
    vpc_id = "${aws_vpc.sonar_vpc.id}"

    #SSH access
    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    #Http access
    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["${var.network_address_space}"]
    }
    #all access open to internet
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        }
    }

########################## Resources  ###########################
resource "aws_instance" "sonar_qube1" {
    ami = "ami-785db401"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    subnet_id = "${aws_subnet.subnet1.id}"
    vpc_security_group_ids = ["${aws_security_group.sonar.id}"]
#   associate_public_ip_address = "true"

    connection {
       user = "ec2_user"
       private_key = "${file(var.private_key_path)}"
    }
}
resource "aws_instance" "sonar_qube2" {
    ami = "ami-785db401"
    instance_type = "t2.micro"
    key_name = "${var.key_name}"
    subnet_id = "${aws_subnet.subnet2.id}"
    vpc_security_group_ids = ["${aws_security_group.sonar.id}"]
#   associate_public_ip_address = "true"

    connection {
       user = "ec2_user"
       private_key = "${file(var.private_key_path)}"
    }
}

resource "aws_elb" "web" {
    name = "sonar-elb"
    subnets = ["${aws_subnet.subnet1.id}","${aws_subnet.subnet2.id}"]
    security_groups = ["${aws_security_group.elb-sg.id}"]
    instances = ["{$aws_instance.sonar_qube2.id}", "${aws_instance.sonar_qube2.id}"]

    listener {
        instance_port = 80
        instance_protocol = "tcp"
        lb_port = 80
        lb_protocol = "tcp"
    }
}


#resource "aws_default_vpc" "default" {
#        tags {
#                    Name = "vpc-938535f6"
#                        }
#}

########################## Output ###########################

output "aws_elb_public_dns" {
      value = "${aws_elb.web.dns_name}"
}
