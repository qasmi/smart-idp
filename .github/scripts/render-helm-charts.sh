#!/bin/bash
set -euo pipefail

# Render Helm charts from ArgoCD Applications
# Finds all ArgoCD Applications with Helm charts, renders them, and saves to /tmp/rendered-manifests/

echo "🔧 Rendering Helm charts from ArgoCD Applications..."
mkdir -p /tmp/rendered-manifests

# Function to render a single Helm chart
render_chart() {
  local app_name="$1"
  local chart="$2"
  local repo_url="$3"
  local target_revision="$4"
  local values="$5"
  
  echo "  Rendering chart: $chart from $repo_url${target_revision:+ (version: $target_revision)}"
  
  # Create repo name from URL
  local repo_name=$(echo "$repo_url" | sed "s/[^a-zA-Z0-9]/-/g" | cut -c1-50)
  
  # Add Helm repo if needed
  if ! helm repo list 2>/dev/null | grep -q "$repo_name"; then
    helm repo add "$repo_name" "$repo_url" 2>/dev/null || {
      echo "    ⚠️  Failed to add repo $repo_url, skipping..."
      return 1
    }
  fi
  helm repo update "$repo_name" 2>/dev/null || true
  
  # Prepare values file if needed
  local values_file=""
  if [ -n "$values" ] && [ "$values" != "null" ] && [ "$values" != "|" ]; then
    values_file=$(mktemp)
    echo "$values" > "$values_file"
  fi
  
  # Render chart
  local output_file="/tmp/rendered-manifests/${app_name}-${chart}-rendered.yaml"
  local helm_cmd="helm template $chart $repo_name/$chart"
  [ -n "$target_revision" ] && [ "$target_revision" != "null" ] && helm_cmd="$helm_cmd --version $target_revision"
  [ -n "$values_file" ] && [ -s "$values_file" ] && helm_cmd="$helm_cmd --values $values_file"
  
  if $helm_cmd > "$output_file" 2>&1; then
    if [ -s "$output_file" ] && ! grep -qi "error" "$output_file"; then
      echo "    ✅ Successfully rendered $chart"
    else
      echo "    ⚠️  Rendering produced errors or empty output"
      rm -f "$output_file"
    fi
  else
    echo "    ⚠️  Failed to render $chart"
    rm -f "$output_file"
  fi
  
  [ -n "$values_file" ] && rm -f "$values_file"
}

# Find all files containing Applications with Helm charts
app_files=$(find demo-cluster -type f \( -name "*.yaml" -o -name "*.yml" \) \
  ! -path "*/.git/*" \
  -exec grep -l "kind: Application" {} \; 2>/dev/null | \
  xargs grep -l "chart:" 2>/dev/null || true)

if [ -z "$app_files" ]; then
  echo "⚠️  No ArgoCD Applications with Helm charts found"
  exit 0
fi

# Process each file
for app_file in $app_files; do
  echo ""
  echo "Processing file: $app_file"
  
  # Extract Application names that have charts
  app_names=$(yq eval-all 'select(.kind == "Application") | 
    select(.spec.source.chart != null or (.spec.sources[0].chart != null)) | 
    .metadata.name' "$app_file" 2>/dev/null | \
    grep -vE "^(null|---|)$")
  
  if [ -z "$app_names" ]; then
    echo "  ⚠️  No Applications with charts found"
    continue
  fi
  
  # Process each Application
  for app_name in $app_names; do
    echo "  Processing Application: $app_name"
    
    # Extract Application document
    temp_app=$(mktemp --suffix=.yaml)
    yq eval-all "select(.kind == \"Application\") | select(.metadata.name == \"$app_name\")" \
      "$app_file" > "$temp_app" 2>/dev/null
    
    # Check if it has multiple sources
    if yq eval '.spec.sources' "$temp_app" 2>/dev/null | grep -q "."; then
      # Multiple sources
      source_count=$(yq eval '.spec.sources | length' "$temp_app" 2>/dev/null || echo "0")
      for i in $(seq 0 $((source_count - 1))); do
        chart=$(yq eval ".spec.sources[$i].chart" "$temp_app" 2>/dev/null)
        repo_url=$(yq eval ".spec.sources[$i].repoURL" "$temp_app" 2>/dev/null)
        target_revision=$(yq eval ".spec.sources[$i].targetRevision" "$temp_app" 2>/dev/null)
        values=$(yq eval ".spec.sources[$i].helm.values" "$temp_app" 2>/dev/null)
        
        if [ -n "$chart" ] && [ "$chart" != "null" ] && [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
          render_chart "$app_name" "$chart" "$repo_url" "$target_revision" "$values"
        fi
      done
    else
      # Single source
      chart=$(yq eval '.spec.source.chart' "$temp_app" 2>/dev/null)
      repo_url=$(yq eval '.spec.source.repoURL' "$temp_app" 2>/dev/null)
      target_revision=$(yq eval '.spec.source.targetRevision' "$temp_app" 2>/dev/null)
      values=$(yq eval '.spec.source.helm.values' "$temp_app" 2>/dev/null)
      
      if [ -n "$chart" ] && [ "$chart" != "null" ] && [ -n "$repo_url" ] && [ "$repo_url" != "null" ]; then
        render_chart "$app_name" "$chart" "$repo_url" "$target_revision" "$values"
      fi
    fi
    
    rm -f "$temp_app"
  done
done

echo ""
echo "✅ Helm chart rendering complete"
echo "📋 Rendered manifests:"
ls -la /tmp/rendered-manifests/ 2>/dev/null || echo "  (none found)"
