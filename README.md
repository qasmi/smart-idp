## smart-idp: GitOps Validation Agent Demo Environment

This repository provides a complete, self-contained demonstration environment for a custom **GitOps Validation Agent**.

The project uses a local **Kind (Kubernetes in Docker) cluster** to deploy the required infrastructure, including **ArgoCD** for managing the deployment pipeline.

### GitOps Validation Pipeline Demo

The core feature of this repository is demonstrating the integrated validation agent:

  * **Trigger:** A GitHub Action is configured to invoke the GitOps Agent on **every commit** made to a Pull Request.
  * **Analysis:** The agent performs a deep analysis of the changes in the GitOps manifest, identifying the semantic diff, potential misconfigurations, and operational risks.
  * **Feedback:** The agent then submits a **detailed diagnostic review** directly to the Pull Request with its complete analysis.

### What This Repository Does

This repository sets up a complete GitOps workflow:

1.  **Demo Environment Setup:** Deploys a local Kind cluster with ArgoCD installed.
2.  **GitOps Bootstrap:** Configures ArgoCD to bootstrap and manage a specified GitOps repository (this repository).
3.  **Application Deployment:** The GitOps pipeline deploys a demo environment including the **kagent** and **kmcp** services.
4.  **Agent Integration:** Provides all necessary configurations and resources required to integrate and deploy the **GitOps Validation Agent**.

# Getting Started

To install the environment and reproduce the validation demo, please follow the detailed instructions below.

## 1\. Infrastructure Setup

Run the following script to install the required tools (like `kubectl`, `kind`, etc.) in your environment:

```bash
playgrounds/kind/infra-setup/setup.sh
```

## 2\. Kubernetes Cluster + ArgoCD + GitOps Bootstrap

The lab runs with [Devbox](https://www.jetify.com/devbox) to manage dependencies:

  * Set up the cluster and bootstrap GitOps:

```bash
cd playgrounds/kind
devbox run setup
```

This command sets up the Kubernetes cluster, installs ArgoCD, and bootstraps the initial GitOps applications (`kagent`, `kmcp`).

## 3\. Deploy GitOps Agent (Configuration and Secrets)

The agent requires API keys for analysis and posting feedback.

### A. Configure Credentials

  * **OpenAI API Key:** Create a Kubernetes Secret in the `kagent` namespace:

    ```bash
    kubectl create secret generic kagent-openai -n kagent --from-literal OPENAI_API_KEY=YOUR-KEY
    ```

  * **GitHub Token (for MCP):** Edit **`demo-resources/github-mcp.yaml`** to inject your GitHub Personal Access Token (PAT).
    *(This token needs read/write permissions for PRs/issues to post the review comment).*

### B. Generate ArgoCD Admin Token

The agent needs an ArgoCD token to perform read-only queries of the live Application state.

1.  **Enable Admin API Access:**
    ```bash
    kubectl -n argocd patch configmap argocd-cm --type merge -p '{"data":{"accounts.admin":"apiKey, login"}}'
    kubectl -n argocd rollout restart deployment argocd-server
    ```
2.  **Generate Token:**
    *(Wait for the `argocd-server` deployment to fully restart before running the next command.)*
    ```bash
    # Log into the server
    kubectl exec -it -n argocd deploy/argocd-server -- argocd login --insecure argocd-server.argocd.svc.cluster.local

    # Generate the API token (copy the output token)
    kubectl exec -it -n argocd deploy/argocd-server -- argocd account generate-token
    ```

### C. Apply Agent Configuration

1.  Edit **`demo-resources/argocd-mcp.yaml`** to inject your GitHub PAT and the generated ArgoCD token.
2.  Apply all configurations and deploy the final GitOps agent:
    ```bash
    kubectl apply -f demo-resources/github-mcp.yaml 
    kubectl apply -f demo-resources/argocd-mcp.yaml 
    kubectl apply -f demo-resources/gitops-agent.yaml 
    ```

## 4\. Expose Kagent Controller

To allow local or CI invocation, forward the controller service port:

```bash
kubectl port-forward svc/kagent-controller 8083:8083 -n kagent
```

## 5\. Invoke GitOps Agent (using the CLI)

Test the agent locally by running it against any manifest file:

```bash
kagent --api-url "http://localhost:8083/api" invoke --agent gitops-agent --file Your-Manifest-file 
```

**P.S. Notes on CI Usage:**

  * **CI Configuration:** The GitHub Action pipeline is already configured to automatically insert the PR ID into the input file before invoking the agent.
  * **CI Access:** For the GitHub Action to work, the `kagent-controller` service must be exposed with a public DNS record that the CI pipeline can access to invoke the agent.

## Clean up

  * Tear down and clean up all resources:

```bash
cd playgrounds/kind
devbox run shutdown
```