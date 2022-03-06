provider "aws" {
    region = "us-east-1"
}

variable "server_port" {
    default = 8080
    description = "The port the server will use for HTTP requests"
}

# output "public_ip" {
#   value = "${aws_launch_configuration.example.associate_public_ip_address}"
# }

output "public_dns" {
  value = "${aws_elb.example.dns_name}"
}

output "availability_zones" {
  value = "${data.aws_availability_zones.all.names}"
}

    # availability_zones = ["${data.aws_availability_zones.all.names}"]

data "aws_availability_zones" "all" {
  
}

resource "aws_security_group" "instance" {
    name = "terraform-example-instance"

    ingress {
        from_port = "${var.server_port}"
        to_port = "${var.server_port}"
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    ingress {
        from_port = "22"
        to_port = "22"
        protocol = "tcp"
        description = "ssh"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    tags = { 
        Name = "terraform-example-instance"
    }
    lifecycle {
      create_before_destroy = true
    }
}


resource "aws_security_group" "elb" {
    name = "terraform-example-elb"

    ingress {
        description = "elb_in"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    # tags = { 
    #     Name = "terraform-example-elb"
    # }
    # lifecycle {
    #   create_before_destroy = true
    # }
}

resource "aws_elb" "example" {
    name = "terraform-asg-example"
    # availability_zones = ["${data.aws_availability_zones.all.names}"]
    availability_zones = ["us-east-1a"]
    
    security_groups = ["${aws_security_group.elb.id}"]
  
    listener {
      lb_port = 80
      lb_protocol = "http"
      instance_port = "${var.server_port}"
      instance_protocol = "http"

    }

    health_check {
      healthy_threshold = 2
      unhealthy_threshold = 2
      timeout = 3
      interval = 30
      target = "HTTP:${var.server_port}/"
    }
}
#sudo apt install python3-pip

resource "aws_launch_configuration" "example" {

# resource "aws_instance" "example" {
    image_id = "ami-04505e74c0741db8d"
    instance_type = "t2.micro"
    security_groups = ["${aws_security_group.instance.id}"]

    user_data = <<-EOF
                #!/bin/bash
                sudo ufw allow "${var.server_port}"
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p "${var.server_port}" &
                echo "hello world"
                EOF
    # tags  {
    #     Name = "terraform-example-launch_configuration"
    #     #   propagate_at_launch = true
    # }
    lifecycle {
      create_before_destroy = true
    }
    
}

resource "aws_autoscaling_group" "example" {
    launch_configuration = "${aws_launch_configuration.example.id}"
    # availability_zones = ["${data.aws_availability_zones.all.names}"]
    availability_zones = ["us-east-1a"]
   
    load_balancers = ["${aws_elb.example.name}"]
    health_check_type = "ELB"

    min_size = 2
    max_size = 10

    tag {
      key = "Name"
      value = "terraform-asg-example"
      propagate_at_launch = true
    }
}
