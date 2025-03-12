FROM mcr.microsoft.com/azure-cli:latest

COPY --from=ghcr.io/opentofu/opentofu:1.9 /usr/local/bin/tofu /usr/local/bin/tofu

ENTRYPOINT ["/bin/bash"]
