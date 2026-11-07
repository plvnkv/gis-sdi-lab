require "yaml"

def check_images(value, label, errors)
  case value
  when Hash
    if value.key?("image")
      image = value["image"]
      if image.is_a?(String)
        reference = image.split("/").last
        pinned = image.match?(/@sha256:[a-f0-9]{64}\z/)
        tagged = !image.include?("@") && reference&.match?(/:[\w][\w.-]*\z/) && !reference.end_with?(":latest")
        errors << "#{label}: image requires an explicit immutable release tag or digest" unless pinned || tagged
      end
    end
    value.each_value { |child| check_images(child, label, errors) }
  when Array
    value.each { |child| check_images(child, label, errors) }
  end
end

errors = []
repo = "https://github.com/plvnkv/gis-sdi-lab.git"
server = "https://kubernetes.default.svc"
STDIN.read.split(/^---\s*$/).each do |document|
  resource = YAML.safe_load(document)
  next if resource.nil?
  abort "Expected a Kubernetes resource mapping" unless resource.is_a?(Hash) && resource["kind"].is_a?(String)

  metadata = resource.fetch("metadata", {})
  label = "#{resource['kind']}/#{metadata['name']}"
  spec = resource.fetch("spec", {})
  case resource["kind"]
  when "Secret"
    errors << "#{label}: Secret is forbidden in public manifests"
  when "PersistentVolumeClaim"
    options = metadata.fetch("annotations", {}).fetch("argocd.argoproj.io/sync-options", "").split(",").map(&:strip)
    errors << "#{label}: PVC requires Prune=false and Delete=false" unless %w[Prune=false Delete=false].all? { |option| options.include?(option) }
  when "Application"
    root = metadata["name"] == "gis-root" && ARGV == ["--root"]
    expected_project, expected_namespace = root ? %w[gis-bootstrap argocd] : %w[gis gis]
    destination = {"server" => server, "namespace" => expected_namespace}
    unless metadata["namespace"] == "argocd" && spec["project"] == expected_project && spec["destination"] == destination
      errors << "#{label}: Application outside GIS project or destination"
    end
    unless spec.dig("source", "repoURL") == repo && spec.dig("source", "targetRevision") == "main" && !spec.key?("sources")
      errors << "#{label}: Application requires approved Git source"
    end
  end
  check_images(spec, label, errors)
end
abort errors.join("\n") unless errors.empty?
