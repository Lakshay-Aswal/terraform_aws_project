resource "aws_vpc" "my_vpc" {
  cidr_block = var.cidr
  tags = {
    Name = "vpc_terra"
  }
}

resource "aws_subnet" "sub1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "ap-south-1a" # Change to your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "sub1_terra"
  }
}

resource "aws_subnet" "sub2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1b" # Change to your desired availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "sub2_terra"
  }
}

resource "aws_internet_gateway" "IGW" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "IGW_terra"
  }
}

resource "aws_route_table" "RT" {
  vpc_id = aws_vpc.my_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGW.id
  }
  tags = {
    Name = "RT_terra"
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.sub1.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.sub2.id
  route_table_id = aws_route_table.RT.id
}

resource "aws_security_group" "sg" {
  name   = "sg_terra"
  vpc_id = aws_vpc.my_vpc.id
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allow SSH from anywhere
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"          # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"] # Allow all outbound traffic
  }

  tags = {
    Name = "sg_terra"
  }
}

resource "aws_s3_bucket" "example" {
  bucket = "lakshay-terraform-bucket-123456789" # Change to a unique bucket name
}

resource "aws_s3_bucket_ownership_controls" "example" {
  bucket = aws_s3_bucket.example.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_acl" "example" {
  depends_on = [
    aws_s3_bucket_ownership_controls.example,
    aws_s3_bucket_public_access_block.example,
  ]

  bucket = aws_s3_bucket.example.id
  acl    = "public-read"
}


resource "aws_instance" "server1" {
  ami                    = "ami-021a584b49225376d"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.sub1.id
  user_data_base64       = base64encode(file("userdata1.sh"))


  tags = {
    Name = "server1"
  }
}

resource "aws_instance" "server2" {
  ami                    = "ami-021a584b49225376d"
  instance_type          = "t2.micro"
  vpc_security_group_ids = [aws_security_group.sg.id]
  subnet_id              = aws_subnet.sub2.id
  user_data_base64       = base64encode(file("userdata2.sh"))


  tags = {
    Name = "server2"
  }
}

#create load balancer

resource "aws_lb" "lb-terra" {
  name                       = "lb-terra"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.sg.id]
  subnets                    = [aws_subnet.sub1.id, aws_subnet.sub2.id]
  enable_deletion_protection = true
  tags = {
    Name = "lb-terra"
  }
}

resource "aws_lb_target_group" "tg-terra" {
  name     = "tg-terra"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  health_check {
    path                = "/"
    port                = "traffic-port"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

}

resource "aws_lb_target_group_attachment" "test1" {
  target_group_arn = aws_lb_target_group.tg-terra.arn
  # Attach the first server to the target group
  target_id = aws_instance.server1.id
  port      = 80
}

resource "aws_lb_target_group_attachment" "test2" {
  target_group_arn = aws_lb_target_group.tg-terra.arn
  # Attach the second server to the target group
  target_id = aws_instance.server2.id
  port      = 80
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.lb-terra.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg-terra.arn
  }
}

output "loadbalancedns" {
  value = aws_lb.lb-terra.dns_name
  
}