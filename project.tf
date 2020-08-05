#Here Let me give details of my provider 
provider "aws" {
  region   = "ap-south-1"
  profile  = "EKS"
}

#Lets create a aws vpc for our use
resource "aws_vpc" "main" {
  cidr_block           = "192.168.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name = "MyVPC"
  }
}

#Its good to notice that map public ip does'nt depends on internet gateway

resource "aws_subnet" "publiclab" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "192.168.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "My_subnet_public_access"
  }  
  map_public_ip_on_launch = true
}

resource "aws_subnet" "privatelab" {
  vpc_id = "${aws_vpc.main.id}"
  cidr_block = "192.168.1.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "My_subnet_private_access"
  }  
}


#Its important to note that terraform does'nt have option to attach or detach internetgateway

resource "aws_internet_gateway" "public_access" {
vpc_id = "${aws_vpc.main.id}"

  tags = {
    Name = "PublicRouter"
  }
}


resource "aws_route_table" "publicroute" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public_access.id
  }

  tags = {
    Name = "Public_route"
  }
}



resource "aws_route_table_association" "join_table" {
  subnet_id      = aws_subnet.publiclab.id
  route_table_id = aws_route_table.publicroute.id
  depends_on     = [ aws_route_table.publicroute ]
}


resource "aws_security_group" "wordpress" {
  name        = "wordpress-sg"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]       
  }
}

resource "aws_security_group" "mysql"{
  name        = "mysql-sg"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.wordpress.id}" ]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    security_groups = [ "${aws_security_group.wordpress.id}" ]
  }
  
   egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]       
  }
}

resource "aws_instance" "mysql" {
  ami                  = "ami-08706cb5f68222d09"
  instance_type        = "t2.micro"
  vpc_security_group_ids  = [ "${aws_security_group.mysql.id}" ]
  subnet_id               = "${aws_subnet.privatelab.id}"
  key_name             = "aws_cloud_key"
  tags = {
    Name = "mysql"
  }
  depends_on = [ aws_security_group.mysql ]
}

output "MySQLprivateIP"{
  value = aws_instance.mysql.private_ip
}

resource "aws_instance" "wordpress" {
  ami                     = "ami-000cbce3e1b899ebd"
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [ "${aws_security_group.wordpress.id}" ]
  subnet_id               = "${aws_subnet.publiclab.id}"
  key_name                = "aws_cloud_key"
  tags = {
    Name = "wordpress"
  }
  depends_on = [ aws_security_group.wordpress ]
}

output "WordpressPublicIP"{
  value = aws_instance.wordpress.public_ip
}

output "WordpressPublicDNS"{
  value = aws_instance.wordpress.public_dns
}

resource "aws_eip" "nat" {
  vpc      = true
}

output "output1" {
  value = aws_eip.nat.id
}

resource "aws_nat_gateway" "gw" {
  allocation_id = aws_eip.nat.id
  subnet_id     = "${aws_subnet.publiclab.id}"

  tags = {
    Name = "NAT"
  }
  depends_on    = [ aws_internet_gateway.public_access ]
}

resource "aws_route_table" "public_cum_private" {
  vpc_id = "${aws_vpc.main.id}"
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.gw.id
  }

  tags = {
    Name = "Public_cum_private"
  }
}

resource "aws_route_table_association" "join_table2" {
  subnet_id      = aws_subnet.privatelab.id
  route_table_id = aws_route_table.public_cum_private.id
  depends_on     = [ aws_route_table.public_cum_private ]
} 
