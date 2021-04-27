
# Terraform - Eks playground
This is just a POC project, therefore, is not meant to be used in a production env.
Nonetheless the idea is to be closer to "production ready" every day while i'm learning.

# Features
1. Clauster Autoscaling
1. Metric Server
1. Nginx Ingress
1. Kong Ingress
1. External-dns
1. CloudWatch with fluentbit
1. Prometheus and Grafana using kube-prometheus-stack
1. HPA using custom metric

# TODO List
1. Improve External-dns security limiting the resource scope
1. Check and fix the pods with local storage, it's preventing clauster-autoscales to scale down