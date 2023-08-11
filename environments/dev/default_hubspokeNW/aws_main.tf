resource "aws_vpc" "paloma-dv-vpc01" {
  cidr_block = "10.11.0.0/24"

  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01"
  }
}

# パブリックサブネットの作成
resource "aws_subnet" "paloma-dv-vpc01-pub-subnet01" {
  provider = aws

  vpc_id            = aws_vpc.paloma-dv-vpc01.id
  cidr_block        = "10.11.0.0/26"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-pub-subnet01"
  }
}

# プライベートサブネットの作成
resource "aws_subnet" "paloma-dv-vpc01-pri-subnet01" {
  provider = aws

  vpc_id            = aws_vpc.paloma-dv-vpc01.id
  cidr_block        = "10.11.0.64/26"
  availability_zone = "ap-northeast-1a"
  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-pri-subnet01"
  }
}

# IGWの作成
resource "aws_internet_gateway" "paloma-dv-vpc01-igw01" {
  vpc_id = aws_vpc.paloma-dv-vpc01.id

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-igw01"
  }
}

# Pubルートテーブルの作成
resource "aws_route_table" "paloma-dv-pub-rt01" {
  vpc_id           = aws_vpc.paloma-dv-vpc01.id
  propagating_vgws = [aws_vpn_gateway.paloma-dv-vpc01-vgw01.id]

  # localのルートはデフォルトで作成される？
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.paloma-dv-vpc01-igw01.id
  }
}

# パブリックサブネットのルートテーブルの関連付け
resource "aws_route_table_association" "paloma-dv-pub_subnet01_association" {
  subnet_id      = aws_subnet.paloma-dv-vpc01-pub-subnet01.id
  route_table_id = aws_route_table.paloma-dv-pub-rt01.id
}

# Priルートテーブルの作成
resource "aws_route_table" "paloma-dv-pri-rt01" {
  vpc_id           = aws_vpc.paloma-dv-vpc01.id
  propagating_vgws = [aws_vpn_gateway.paloma-dv-vpc01-vgw01.id]
}

# プライベートサブネットのルートテーブルの関連付け
resource "aws_route_table_association" "paloma-dv-pri_subnet01_association" {
  subnet_id      = aws_subnet.paloma-dv-vpc01-pri-subnet01.id
  route_table_id = aws_route_table.paloma-dv-pri-rt01.id
}

# SSM接続用IAMロール
resource "aws_iam_role" "paloma-dv-iam-role-ssm" {
  name               = "${var.aws_resname_prefix}-iam-role-ssm"
  description        = "Allows EC2 instances to call AWS services on your behalf"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  tags = {
    Name = "${var.aws_resname_prefix}-iam-role-SSM"
  }
}

resource "aws_iam_role_policy_attachment" "paloma-dv-iam-role-ssm" {
  role       = aws_iam_role.paloma-dv-iam-role-ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "paloma-dv-instance-profile01" {
  count = var.is_create_aws_instance

  name = "${var.aws_resname_prefix}-instance-profile01"
  role = aws_iam_role.paloma-dv-iam-role-ssm.name
}

# EC2インスタンス（パブリックサブネット）
resource "aws_instance" "paloma-dv-pub-instance01" {
  count = var.is_create_aws_instance

  provider = aws

  ami                         = "ami-0bc23e4337e8bc5ea" # Amazon Linuxを選択
  instance_type               = "t2.micro"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pub-subnet01.id
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pub-sg01.id]
  tags = {
    Name = "${var.aws_resname_prefix}-pub-instance01"
  }
}

# EC2インスタンス（プライベートサブネット Linux）
resource "aws_instance" "paloma-dv-pri-linux-instance01" {
  count = var.is_create_aws_instance

  provider = aws

  ami                         = "ami-0d739893974bd27d0" # Amazon Linux2を選択
  instance_type               = "t2.micro"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pri-subnet01.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 20
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pri-sg01.id]
  tags = {
    Name = "${var.aws_resname_prefix}-pri-linux-instance01"
  }
}

# EC2インスタンス（プライベートサブネット Windows）
resource "aws_instance" "paloma-dv-pri-win-instance01" {
  count = var.is_create_aws_instance

  provider = aws

  ami                         = "ami-0222cfd6a9c020197" # Windows_Server-2022-English-Full-Base-2023.07.12
  instance_type               = "t2.large"
  key_name                    = "paloma-pr-keypair01"
  subnet_id                   = aws_subnet.paloma-dv-vpc01-pri-subnet01.id
  associate_public_ip_address = false
  iam_instance_profile        = aws_iam_instance_profile.paloma-dv-instance-profile01[0].name

  # ディスク
  root_block_device {
    volume_type = "gp2"
    volume_size = 50
  }

  vpc_security_group_ids = [aws_security_group.paloma-dv-pri-sg01.id]
  tags = {
    Name = "${var.aws_resname_prefix}-pri-win-instance01"
  }
}


# パブリックサブネットのEC2用セキュリティグループ
resource "aws_security_group" "paloma-dv-pub-sg01" {
  name        = "paloma-dv-pub-sg01"
  description = "Allow public access"
  vpc_id      = aws_vpc.paloma-dv-vpc01.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = -1
    security_groups = [aws_security_group.paloma-dv-pri-sg01.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.aws_resname_prefix}-pub-sg01"
  }
}

# プライベートサブネットのEC2用セキュリティグループ
resource "aws_security_group" "paloma-dv-pri-sg01" {
  name        = "paloma-dv-pri-sg01"
  description = "Allow local access"
  vpc_id      = aws_vpc.paloma-dv-vpc01.id

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  /* Cycleエラーを回避するため、sg外で定義
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/24"]
    security_groups = [aws_security_group.paloma-dv-pub-sg01.name]
  }
*/
  tags = {
    Name = "${var.aws_resname_prefix}-pri-sg01"
  }
}

# Cycleエラーを回避するため、pri-sg01の sg向け egressルールを外だし（SG Ruleで定義）
resource "aws_security_group_rule" "paloma-dv-pri-sg01-rule-egress" {
  security_group_id        = aws_security_group.paloma-dv-pri-sg01.id
  type                     = "egress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.paloma-dv-pub-sg01.id
}

# GCP VPCへのEgress許可を追加
resource "aws_security_group_rule" "paloma-dv-pri-sg01-rule-egress-gcp" {
  security_group_id = aws_security_group.paloma-dv-pri-sg01.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks = [
    "10.1.0.0/24"
  ]

}

# SSM用VPC Endpoint用セキュリティグループ
resource "aws_security_group" "paloma-dv-vpce-sg01" {
  count = var.is_create_aws_instance

  name        = "paloma-dv-vpce-sg01"
  description = "Allow local access"
  vpc_id      = aws_vpc.paloma-dv-vpc01.id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.paloma-dv-vpc01.cidr_block]
  }

  tags = {
    Name = "${var.aws_resname_prefix}-vpce-sg01"
  }
}


# SSM用VPC Endpointの作成（ループで作成してみる）
/**** TODO：削除　一時的に残している
locals {
  vpc_endpoint_services = ["ssm", "ssmmessages", "ec2messages"]
}

resource "aws_vpc_endpoint" "paloma-dv-vpc-endpoint-ssm" {
  for_each = toset(local.vpc_endpoint_services)

  vpc_id              = aws_vpc.paloma-dv-vpc01.id
  service_name        = "com.amazonaws.ap-northeast-1.${each.value}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  subnet_ids = [aws_subnet.paloma-dv-vpc01-pri-subnet01.id]
  security_group_ids = [
    aws_security_group.paloma-dv-vpce-sg01.id
  ]
  tags = {
    Name = "${var.aws_resname_prefix}-vpc-endpoint-${each.value}"
  }
}
*/

module "paloma-dv-vpc-endpoint-ssm" {
  count = var.is_create_aws_instance

  source = "../../../modules/aws_ssm_vpce"

  vpc_id               = aws_vpc.paloma-dv-vpc01.id
  subnet_id            = aws_subnet.paloma-dv-vpc01-pri-subnet01.id
  security_group_id    = aws_security_group.paloma-dv-vpce-sg01[0].id
  resource_name_prefix = var.aws_resname_prefix

}


# 仮想プライベートゲートウェイの設定
resource "aws_vpn_gateway" "paloma-dv-vpc01-vgw01" {
  vpc_id          = aws_vpc.paloma-dv-vpc01.id
  amazon_side_asn = 65512

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-vgw01"
  }
}

/* Private Routeの作成時に伝搬を設定しているので、おそらくそれでOKなはず
// 仮想プライベートゲートウェイのルート伝播の設定
resource "aws_vpn_gateway_route_propagation" "cmk_vgw_rp" {
  vpn_gateway_id = aws_vpn_gateway.paloma-dv-vgw.id
  route_table_id = var.aws_vpc_route_table_id
}
*/

// 1つ目のカスタマーゲートウェイの設定
resource "aws_customer_gateway" "paloma-dv-vpc01-cgw01" {
  count = var.is_create_aws_instance

  bgp_asn    = 65513
  ip_address = google_compute_ha_vpn_gateway.hub_vpc_havpn_gw[0].vpn_interfaces[0].ip_address
  type       = "ipsec.1"

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-cgw01"
  }
}
// 1つ目のサイト間のVPN接続の設定
resource "aws_vpn_connection" "paloma-dv-vpc01-vpn01" {
  count = var.is_create_aws_instance

  vpn_gateway_id      = aws_vpn_gateway.paloma-dv-vpc01-vgw01.id
  customer_gateway_id = aws_customer_gateway.paloma-dv-vpc01-cgw01[0].id
  type                = "ipsec.1"

  tags = {
    Name = "${var.aws_resname_prefix}-vpc01-vpn01"
  }
}