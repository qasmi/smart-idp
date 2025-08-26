PATH_DIR := ./scripts
CONFIG   := $(PATH_DIR)/config.yaml
TMP      := $(PATH_DIR)/tmp.yaml
OUTPUT   := ./.k8s-gen/manifests.yaml

all: generate clean

generate:
	@echo "Cleaning and preparing directory..."
	rm -rf $(PATH_DIR) && mkdir -p $(PATH_DIR)
	echo "applications: []" > $(CONFIG)

	@echo "Merging config..."
	yq eval-all 'select(fileIndex > 0) as $$item ireduce ([]; . + $$item) | {"applications": .}' \
		$(CONFIG) ./team-*/apps.yaml > $(TMP) && mv $(TMP) $(CONFIG)

	yq eval-all '.projects as $$item ireduce ({}; . * {"projects": $$item})' ./team-*/projects.yaml >> $(CONFIG)

	echo "" >> $(CONFIG)
	yq eval-all '.namespaces as $$item ireduce ({}; . * {"namespaces": $$item})' ./team-*/namespaces.yaml >> $(CONFIG)

	cat global.yaml >> $(CONFIG)

	@echo "Rendering Helm template..."
	helm template ../gitops-chart --values $(CONFIG) > $(OUTPUT)

	@echo "Manifests generated at $(OUTPUT)"

clean:
	rm -rf $(PATH_DIR)
	@echo "Cleaned up generated files."
