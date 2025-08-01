
# tauri (tauri)

Install Tauri requirements and CLI

## Example Usage

```json
"features": {
    "ghcr.io/olivierlemasle/devcontainers-features/tauri:1": {}
}
```

## Options

| Options Id | Description | Type | Default Value |
|-----|-----|-----|-----|
| version | Select the version of Tauri CLI to install. | string | latest |

## Customizations

### VS Code Extensions

- `tauri-apps.tauri-vscode`



## Requirements

This feature **requires** an installation of Rust. You may:
- use the [`mcr.microsoft.com/devcontainers/rust`](https://github.com/devcontainers/images/tree/main/src/rust) image or the [`rust`](https://hub.docker.com/_/rust) image
- or use the [`ghcr.io/devcontainers/features/rust`](https://github.com/devcontainers/features/tree/main/src/rust) feature
- or [install by yourself Rust](https://www.rust-lang.org/tools/install) (`cargo` and `rustc` are required).

A NodeJS installation is also **recommended**. You may use the [`ghcr.io/devcontainers/features/node`](https://github.com/devcontainers/features/tree/main/src/node) feature.

---

_Note: This file was auto-generated from the [devcontainer-feature.json](https://github.com/olivierlemasle/devcontainers-features/blob/main/src/tauri/devcontainer-feature.json).  Add additional notes to a `NOTES.md`._
