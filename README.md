# Cloud Infrastructure Monitoring with Prometheus and Grafana on AWS

Terraform provisions two Ubuntu 22.04 EC2 instances on AWS, and Ansible configures them:

- **monitor-server**: runs Prometheus (metrics collection) and Grafana (dashboards)
- **target-server**: the machine being monitored, running Node Exporter

Everything is automated. One `terraform apply` builds the servers, generates the
Ansible inventory and the Prometheus config, and installs the full monitoring stack.

## Architecture

    Terraform --> AWS (2 x EC2 + security group + key pair)
                      |
    Ansible ----------+--> Node Exporter on both servers
                      +--> Prometheus + Grafana on monitor-server

    Prometheus scrapes Node Exporter (port 9100) on both servers every 15s.
    Grafana reads from Prometheus and displays the dashboards.

## Files

- `main.tf`: provider, AMI lookup, key pair, security group, 2 EC2 instances, generated inventory and Prometheus config
- `variables.tf`: region, instance_type, key_name, public_key_path
- `outputs.tf`: server IPs and the Grafana and Prometheus URLs
- `prometheus.yml.tpl`: Prometheus config template (Terraform fills in the server IPs)
- `playbook.yml`: Ansible playbook (Node Exporter, Prometheus, Grafana, data source)

## Metrics monitored

| Metric | Source |
|---|---|
| CPU usage % | node_cpu_seconds_total |
| Memory usage % | node_memory_MemAvailable_bytes, node_memory_MemTotal_bytes |
| Disk usage % | node_filesystem_avail_bytes, node_filesystem_size_bytes |
| Network in/out | node_network_receive_bytes_total, node_network_transmit_bytes_total |

## Deploy

Requirements: Terraform, Ansible, AWS CLI configured, and an SSH key at ~/.ssh/prestashop-key.

    terraform init
    terraform plan
    terraform apply

When it finishes, open the `grafana_url` output (login admin / admin, change the password on first login).

## Clean up

    terraform destroy

## Screenshots

See the `screenshots/` folder.
