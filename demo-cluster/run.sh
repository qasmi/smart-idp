path="./.gitops-scripts"
rm -rf $path && mkdir $path
echo "applications: []" > $path/config.yaml
yq eval-all 'select(fileIndex > 0) as $item ireduce ([]; . + $item) | {"applications": .}' \
$path/config.yaml ./team-*/apps.yaml > $path/tmp.yaml && mv $path/tmp.yaml $path/config.yaml
yq eval-all '.projects as $item ireduce ({}; . * {"projects": $item})' ./team-*/projects.yaml >> $path/config.yaml
echo "" >> $path/config.yaml
yq eval-all '.namespaces as $item ireduce ({}; . * {"namespaces": $item})' ./team-*/namespaces.yaml >> $path/config.yaml
cat global.yaml >> $path/config.yaml

docker run --rm \
  -v "${PWD}:/work" \
  -v "$(realpath ../gitops-chart):/chart" \
  -w /work \
  alpine/helm \
  template /chart --values $path/config.yaml > ./.k8s-gen-output/manifests.yaml
  
rm -rf $path