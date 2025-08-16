data "external" "minikube_ip" {
	count = var.enable_ingress && var.minikube_ip_override == "" ? 1 : 0
	# Emit JSON: {"ip":"<address>"}; fallback to 127.0.0.1 if minikube not available (pre-cluster)
	program = [
		"bash",
		"-c",
		"ip=$(minikube ip 2>/dev/null || echo 127.0.0.1); echo '{\"ip\":\"'$ip'\"}'"
	]
}

locals {
		resolved_minikube_ip = var.minikube_ip_override != "" ? var.minikube_ip_override : (
			var.enable_ingress ? data.external.minikube_ip[0].result.ip : ""
		)
	ingress_domain_base = local.resolved_minikube_ip != "" ? "${local.resolved_minikube_ip}.nip.io" : ""
	jenkins_host        = local.ingress_domain_base != "" ? "jenkins.${local.ingress_domain_base}" : ""
	grafana_host        = local.ingress_domain_base != "" ? "grafana.${local.ingress_domain_base}" : ""
	prometheus_host     = local.ingress_domain_base != "" ? "prometheus.${local.ingress_domain_base}" : ""
}

# Run local port-forwards automatically after key Helm releases are applied (optional convenience)
resource "null_resource" "start_port_forwards" {
	# Re-run if script content or dependent releases change
	triggers = {
		script_sha = filesha256("${path.root}/../scripts/port-forward.sh")
		jenkins_id = try(helm_release.jenkins.id, "")
		prom_id    = try(helm_release.kube_prometheus_stack.id, "")
	}

	provisioner "local-exec" {
		command = "bash ${path.root}/../scripts/port-forward.sh"
		interpreter = ["/bin/bash", "-c"]
	}

	depends_on = [helm_release.jenkins, helm_release.kube_prometheus_stack]
}

# Root module previously empty; now provides shared locals for ingress.
