global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"
    static_configs:
      - targets: ["${monitor_ip}:9100"]
        labels:
          server: "monitor-server"
      - targets: ["${target_ip}:9100"]
        labels:
          server: "target-server"
