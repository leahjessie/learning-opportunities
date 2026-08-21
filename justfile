set shell := ["bash", "-eu", "-o", "pipefail", "-c"]
dotfiles := env_var_or_default("DOTFILES", env_var("HOME") + "/Developer/personal/dotfiles")

default:
    @just --list

# Show dirty, unpublished, and undeployed state across the agent runtime.
agent-runtime-status:
    just --justfile "{{ dotfiles }}/justfile" agent-runtime-status

# Deploy this repo only; unrelated dirty repos do not block it.
deploy-mini:
    "{{ dotfiles }}/scripts/mini-workflows" deploy learning-opportunities

# Deploy this repo plus matching dotfiles wiring.
deploy-mini-with-dotfiles:
    "{{ dotfiles }}/scripts/mini-workflows" deploy learning-opportunities dotfiles

# Deploy every repo currently registered in the coordinated agent runtime.
deploy-agent-runtime:
    just --justfile "{{ dotfiles }}/justfile" deploy-agent-runtime
