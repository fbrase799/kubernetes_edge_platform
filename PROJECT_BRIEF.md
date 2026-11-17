= Collected Project Notes

*Name*

kubernetes_edge_plattform

*Purpose*

- focus on kubernetes with integrating edge devices and serving as a plattform
- build, deploy, operate and maintain self-hosted kubernetes infrastructure
- demonstrate practical Kubernetes infrastructure engineering, including cluster provisioning, container orchestration, monitoring and recovery

*Requirements*

1. Infrastructure as Code shall be used for environment setup using k3b configuration files
2. Kubernetes shall orchestrate a "C++ Open-Gateway" project, InfluxDB and Grafana
3. Edge integration of sensors is done via "C++ Open-Gateway" and it's API shall be used to connect the sensor data with InfluxDB and Grafana
4. Kubernetes shall run as a multi-node cluster
5. Application deployment shall be done via Kubernetes manifests and Helm charts
6. Kubernetes services and access to Grafana shall be configured
7. InfluxDB shall preserve measurements across Pod restarts
8. Pod recovery, scaling and rolling updates shall be demonstrated
9. Logs from kubernetes cluster shall be visible in Grafana to verify behaviour in scenarios

*Temporary*

1. for first integration until a working tagged version is available the "C++ Open Gateway" shall be included as a submodule