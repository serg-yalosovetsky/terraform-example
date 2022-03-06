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
  value = aws_lb.example.dns_name
  description = "The domain name of the load balancer"
}

output "availability_zones" {
  value = data.aws_availability_zones.all.names
}

    # availability_zones = ["${data.aws_availability_zones.all.names}"]

data "aws_availability_zones" "all" {
  
}

data "aws_vpc" "default" {
  default = true
}


data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnets" "default" {
  # aws_vpc = data.aws_vpc.default.id
  # vpc_id = 
   filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
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


resource "aws_security_group" "alb" {
    name = "terraform-example-alb"

    ingress {
        description = "lb_in"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

    egress {
        description = "lb_out"
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = [ "0.0.0.0/0" ]
    }

}

resource "aws_lb" "example" {
    name = "terraform-asg-example"
    # availability_zones = ["${data.aws_availability_zones.all.names}"]
    # availability_zones = ["us-east-1a"]
    load_balancer_type = "application"
    subnets = data.aws_subnet_ids.default.ids
    security_groups = [aws_security_group.alb.id]

}

resource "aws_lb_target_group" "asg" {
  name = "terraform-asg-example"
  port = var.server_port
  protocol = "HTTP"
  vpc_id = data.aws_subnet_ids.default.id

  health_check {
    path = "/"
    protocol = "HTTP"
    matcher = "200"
    interval = 15
    timeout = 3
    healthy_threshold = 2
    unhealthy_threshold = 2
  }   

  # lifecycle {
  #   create_before_destroy = true
  #   ignore_changes        = [name]
  # }

}

resource "aws_lb_listener" "http" {

    load_balancer_arn = aws_lb.example.arn

    port = 80
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
      }
    }   
  
}


resource "aws_lb_listener_rule" "asg" {

    listener_arn = aws_lb_listener.http.arn
    priority = 100

    condition {
      path_pattern {
        values = ["*"]
      }
    }

    action {
      type = "forward"
      target_group_arn = aws_lb_target_group.asg.arn
    }   
  
}

resource "aws_launch_configuration" "example" {

# resource "aws_instance" "example" {
    image_id = "ami-04505e74c0741db8d"
    # image_id = "ami-0c55b159cb­fafe1f0"
    
    instance_type = "t2.micro"
    security_groups = [aws_security_group.instance.id]

    user_data = <<-EOF
                #!/bin/bash
                # sudo ufw allow "${var.server_port}"
                echo "Hello, World" > index.html
                nohup busybox httpd -f -p ${var.server_port} &
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
    launch_configuration = aws_launch_configuration.example.name
    # availability_zones = ["${data.aws_availability_zones.all.names}"]
    vpc_zone_identifier = data.aws_subnet_ids.default.ids
    # availability_zones = ["us-east-1a"]

    target_group_arns = [aws_lb_target_group.asg.arn]
    health_check_type = "ELB"

    # load_balancers = [aws_elb.example.name]

    min_size = 2
    max_size = 10

    tag {
      key = "Name"
      value = "terraform-asg-example"
      propagate_at_launch = true
    }
}
