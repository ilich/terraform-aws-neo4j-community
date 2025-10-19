locals {
  region = var.region != null ? var.region : data.aws_region.current.region

  user_data = <<-EOF
    #!/bin/bash
    set -euo pipefail
    echo Running startup script...

    password="${var.password}"

    cat <<EOFR > /etc/yum.repos.d/neo4j.repo
    [neo4j]
    name=Neo4j RPM Repository
    baseurl=https://yum.neo4j.com/stable/latest
    enabled=1
    gpgcheck=1
    EOFR
    sleep 100

    install_neo4j_from_yum() {
      echo "Installing Graph Database..."
       PACKAGE_VERSION=$(curl --fail http://versions.neo4j-templates.com/target.json | jq -r '.aws."latest"' || echo "")
          if [[ ! -z $PACKAGE_VERSION && $PACKAGE_VERSION != "null" ]]; then
            echo "Found PACKAGE_VERSION from http://versions.neo4j-templates.com : PACKAGE_VERSION=$PACKAGE_VERSION"
            NEO4J_YUM_PACKAGE="neo4j-$PACKAGE_VERSION"
          else
            echo 'Failed to resolve Neo4j version from http://versions.neo4j-templates.com, using PACKAGE_VERSION=latest'
            PACKAGE_VERSION="latest"
            NEO4J_YUM_PACKAGE='neo4j-enterprise'
          fi
        rpm --import https://debian.neo4j.com/neotechnology.gpg.key
        yum -y install "$${NEO4J_YUM_PACKAGE}"
        echo "Neo4j installed."
        yum update -y aws-cfn-bootstrap
        systemctl enable neo4j
        if [[ "$PACKAGE_VERSION" == "latest" ]]; then
          PACKAGE_VERSION=$(/usr/share/neo4j/bin/neo4j --version)
        fi
    }

    install_apoc_plugin() {
      echo "Installing APOC..."
      mv /var/lib/neo4j/labs/apoc-*-core.jar /var/lib/neo4j/plugins
    }

    extension_config() {
      echo Configuring extensions and security in neo4j.conf...
      sed -i s~#server.unmanaged_extension_classes=org.neo4j.examples.server.unmanaged=/examples/unmanaged~server.unmanaged_extension_classes=com.neo4j.bloom.server=/bloom,semantics.extension=/rdf~g /etc/neo4j/neo4j.conf
      sed -i s/#dbms.security.procedures.unrestricted=my.extensions.example,my.procedures.*/dbms.security.procedures.unrestricted=apoc.*,bloom.*/g /etc/neo4j/neo4j.conf
      echo "dbms.security.http_auth_allowlist=/,/browser.*,/bloom.*" >> /etc/neo4j/neo4j.conf
      echo "dbms.security.procedures.allowlist=apoc.*,bloom.*" >> /etc/neo4j/neo4j.conf
    }

    build_neo4j_conf_file() {
      privateIP="$(hostname -i | awk '{print $NF}')"
      echo "Configuring network in neo4j.conf..."
      sed -i 's/#server.default_listen_address=0.0.0.0/server.default_listen_address=0.0.0.0/g' /etc/neo4j/neo4j.conf
      sed -i s/#server.default_advertised_address=localhost/server.default_advertised_address="$${privateIP}"/g /etc/neo4j/neo4j.conf
      sed -i s/#server.bolt.listen_address=:7687/server.bolt.listen_address=0.0.0.0:7687/g /etc/neo4j/neo4j.conf
      sed -i s/#server.bolt.advertised_address=:7687/server.bolt.advertised_address="$${privateIP}":7687/g /etc/neo4j/neo4j.conf
      sed -i s/#server.http.listen_address=:7474/server.http.listen_address=0.0.0.0:7474/g /etc/neo4j/neo4j.conf
      sed -i s/#server.http.advertised_address=:7474/server.http.advertised_address="$${privateIP}":7474/g /etc/neo4j/neo4j.conf
      echo "internal.dbms.cypher_ip_blocklist=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,169.254.169.0/24,fc00::/7,fe80::/10,ff00::/8" >> /etc/neo4j/neo4j.conf
      neo4j-admin server memory-recommendation | grep -v ^# >> /etc/neo4j/neo4j.conf
    }

    start_neo4j() {
      echo "Starting Neo4j..."
      systemctl start neo4j
      neo4j-admin dbms set-initial-password "$${password}"
      while [[ "$(curl -s -o /dev/null -m 3 -L -w '%%{http_code}' http://localhost:7474 )" != "200" ]];
        do echo "Waiting for neo4j to start"
        sleep 5
      done
    }

    enable_ssm() {
      echo "Enabling SSM Session Manager..."
      systemctl enable amazon-ssm-agent
      systemctl start amazon-ssm-agent
    }

    install_neo4j_from_yum
    install_apoc_plugin
    extension_config
    build_neo4j_conf_file
    start_neo4j
    enable_ssm
    EOF
}

data "aws_region" "current" {}

# AMIs for al2023-ami-2023.9.20250929.0-kernel-6.1-x86_64
locals {
  ami_map = {
    "ap-south-1"     = "ami-0f9708d1cd2cfee41"
    "eu-north-1"     = "ami-04c08fd8aa14af291"
    "eu-west-3"      = "ami-0d8c6c2b092ebb980"
    "eu-west-2"      = "ami-0336cdd409ab5eec4"
    "eu-west-1"      = "ami-04f25a69b566c844b"
    "ap-northeast-3" = "ami-0c3d48d3539dae8d5"
    "ap-northeast-2" = "ami-099099dff4384719c"
    "ap-northeast-1" = "ami-0d4aa492f133a3068"
    "ca-central-1"   = "ami-029c5475368ac7adc"
    "sa-east-1"      = "ami-07c0cae188e21a093"
    "ap-southeast-1" = "ami-088d74defe9802f14"
    "ap-southeast-2" = "ami-0c462b53550d4fca8"
    "eu-central-1"   = "ami-08697da0e8d9f59ec"
    "us-east-1"      = "ami-052064a798f08f0d3"
    "us-east-2"      = "ami-077b630ef539aa0b5"
    "us-west-1"      = "ami-0b967c22fe917319b"
    "us-west-2"      = "ami-0caa91d6b7bee0ed0"
  }
}

resource "aws_iam_role" "neo4j_ssm" {
  name_prefix = "neo4j-ssm-"
  description = "IAM role for Neo4j EC2 instance to use SSM Session Manager"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "neo4j_ssm" {
  role       = aws_iam_role.neo4j_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "neo4j" {
  name_prefix = "neo4j-"
  role        = aws_iam_role.neo4j_ssm.name

  tags = var.tags
}

resource "aws_security_group" "neo4j" {
  name_prefix = "neo4j-"
  description = "Enable Neo4j External Ports"
  vpc_id      = var.vpc_id

  ingress {
    description = "Neo4j Browser HTTP"
    from_port   = 7474
    to_port     = 7474
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Neo4j Bolt Protocol"
    from_port   = 7687
    to_port     = 7687
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_instance" "neo4j" {
  ami                  = lookup(local.ami_map, local.region, local.ami_map["us-east-1"])
  instance_type        = var.instance_type
  subnet_id            = var.subnet_id
  iam_instance_profile = aws_iam_instance_profile.neo4j.name

  vpc_security_group_ids = [aws_security_group.neo4j.id]

  ebs_optimized = true

  root_block_device {
    volume_size           = var.disk_size
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = var.snapshot_retention_days > 0 ? merge(
      var.tags,
      {
        "neo4j-snapshot" = "true"
      }
    ) : var.tags
  }

  user_data = local.user_data

  tags = var.tags

  lifecycle {
    ignore_changes = [ami]
  }
}

resource "aws_iam_role" "dlm_lifecycle_role" {
  count       = var.snapshot_retention_days > 0 ? 1 : 0
  name_prefix = "neo4j-dlm-lifecycle-"
  description = "IAM role for Data Lifecycle Manager to manage Neo4j EBS snapshots"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "dlm.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dlm_lifecycle" {
  count = var.snapshot_retention_days > 0 ? 1 : 0
  name  = "neo4j-dlm-lifecycle-policy"
  role  = aws_iam_role.dlm_lifecycle_role[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateSnapshot",
          "ec2:CreateSnapshots",
          "ec2:DeleteSnapshot",
          "ec2:DescribeVolumes",
          "ec2:DescribeInstances",
          "ec2:DescribeSnapshots"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateTags"
        ]
        Resource = "arn:aws:ec2:*::snapshot/*"
      }
    ]
  })
}

resource "aws_dlm_lifecycle_policy" "neo4j_snapshots" {
  count              = var.snapshot_retention_days > 0 ? 1 : 0
  description        = "Daily snapshots for Neo4j EBS volumes with ${var.snapshot_retention_days} day retention"
  execution_role_arn = aws_iam_role.dlm_lifecycle_role[0].arn
  state              = "ENABLED"

  policy_details {
    resource_types = ["VOLUME"]

    schedule {
      name = "Daily Neo4j snapshots"

      create_rule {
        interval      = 24
        interval_unit = "HOURS"
        times         = ["03:00"]
      }

      retain_rule {
        count = var.snapshot_retention_days
      }

      tags_to_add = merge(
        var.tags,
        {
          "SnapshotType" = "DLM"
          "Service"      = "Neo4j"
        }
      )

      copy_tags = true
    }

    target_tags = {
      "neo4j-snapshot" = "true"
    }
  }

  tags = var.tags
}
