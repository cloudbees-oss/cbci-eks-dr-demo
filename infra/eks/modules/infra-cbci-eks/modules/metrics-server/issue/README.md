# Issue with Metric Server

Following the instructions per [Installing the Kubernetes Metrics Server - Amazon EKS](https://docs.aws.amazon.com/eks/latest/userguide/metrics-server.html)

I'm fancing the following problem:

```bash

$> kubectl top nodes
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get nodes.metrics.k8s.io)
...

$> kubectl top pods
Error from server (ServiceUnavailable): the server is currently unable to handle the request (get pods.metrics.k8s.io)
...

```

As a result I have modified the [components.yaml](components.yaml) accroding to the following references but not luck

* https://k21academy.com/docker-kubernetes/the-server-is-currently-unable-to-handle-the-request/
* https://www.linuxsysadmins.com/service-unavailable-kubernetes-metrics/