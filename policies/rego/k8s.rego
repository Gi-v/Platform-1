package main

# Deny containers without resource limits
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.cpu
  msg := sprintf("Container '%s' in Deployment '%s' must set CPU limits", [container.name, input.metadata.name])
}

deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.resources.limits.memory
  msg := sprintf("Container '%s' in Deployment '%s' must set memory limits", [container.name, input.metadata.name])
}

# Deny missing required labels
required_labels := {"app.kubernetes.io/name", "team"}

deny[msg] {
  input.kind == "Deployment"
  label := required_labels[_]
  not input.metadata.labels[label]
  msg := sprintf("Deployment '%s' is missing required label: %s", [input.metadata.name, label])
}

# Deny latest tag
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  endswith(container.image, ":latest")
  msg := sprintf("Container '%s' must not use :latest tag", [container.name])
}

# Deny privileged containers
deny[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  container.securityContext.privileged == true
  msg := sprintf("Container '%s' must not run as privileged", [container.name])
}

# Warn on missing readiness probe
warn[msg] {
  input.kind == "Deployment"
  container := input.spec.template.spec.containers[_]
  not container.readinessProbe
  msg := sprintf("Container '%s' should have a readinessProbe", [container.name])
}
