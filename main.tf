resource "aws_vpc" "udagram_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name    = "${var.project}-vpc"
    project = var.project
  }
}


resource "aws_route_table" "udagram_rt" {
  vpc_id = aws_vpc.udagram_vpc.id

  tags = {
    Name    = "${var.project}-rt"
    project = var.project
  }
}


resource "aws_internet_gateway" "udagram_igw" {
  vpc_id = aws_vpc.udagram_vpc.id

  tags = {
    Name    = "${var.project}-igw"
    project = var.project
  }
}

resource "aws_route" "egress_traffic" {
  route_table_id         = aws_route_table.udagram_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.udagram_igw.id
}

resource "aws_eip" "udagram_eip1" {
  depends_on = [aws_internet_gateway.udagram_igw]

  vpc = true

  tags = {
    Name    = "${var.project}-eip1"
    project = var.project
  }
}

resource "aws_eip" "udagram_eip2" {
  depends_on = [aws_internet_gateway.udagram_igw]

  vpc = true

  tags = {
    Name    = "${var.project}-eip2"
    project = var.project
  }
}

resource "aws_subnet" "udagram_sn1" {
  vpc_id     = aws_vpc.udagram_vpc.id
  cidr_block = var.subnets[0]

  tags = {
    Name    = "${var.project}-sn1"
    project = var.project
  }
}

resource "aws_route_table_association" "udagram_sn1_rt" {
  subnet_id      = aws_subnet.udagram_sn1.id
  route_table_id = aws_route_table.udagram_rt.id
}

resource "aws_subnet" "udagram_sn2" {
  vpc_id     = aws_vpc.udagram_vpc.id
  cidr_block = var.subnets[1]

  tags = {
    Name    = "${var.project}-sn2"
    project = var.project
  }
}

resource "aws_route_table_association" "udagram_sn2_rt" {
  subnet_id      = aws_subnet.udagram_sn2.id
  route_table_id = aws_route_table.udagram_rt.id
}

resource "aws_nat_gateway" "udagram_sn1_gw" {
  depends_on = [aws_subnet.udagram_sn1, aws_internet_gateway.udagram_igw]

  allocation_id = aws_eip.udagram_eip1.id
  subnet_id     = aws_subnet.udagram_sn1.id

  tags = {
    Name    = "${var.project}-sn1_gw"
    project = var.project
  }
}

resource "aws_nat_gateway" "udagram_sn2_gw" {
  depends_on = [aws_subnet.udagram_sn2, aws_internet_gateway.udagram_igw]

  allocation_id = aws_eip.udagram_eip2.id
  subnet_id     = aws_subnet.udagram_sn2.id

  tags = {
    Name    = "${var.project}-sn2_gw"
    project = var.project
  }
}

resource "aws_security_group" "udagram_sg" {
  description = "Allow HTTP inbound traffic"
  vpc_id      = aws_vpc.udagram_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project}-sg"
    project = var.project
  }
}

resource "aws_security_group_rule" "allow_http_in" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.udagram_sg.id
}

resource "aws_security_group_rule" "allow_ssh_in" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.udagram_sg.id
}