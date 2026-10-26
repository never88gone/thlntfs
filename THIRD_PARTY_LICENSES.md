# Third-Party Notices & Licenses

THLNTFS utilizes several third-party open-source components. Each retains its own upstream license as listed below. These components run as independent sub-processes or guest kernel images in accordance with open-source aggregation requirements.

| Component | License | Source | Usage |
|---|---|---|---|
| [anylinuxfs](https://github.com/nohajc/anylinuxfs) | GPL-3.0 | `github.com/nohajc/anylinuxfs` | Git submodule at `vendor/src/anylinuxfs`, built from source into `vendor/bin/anylinuxfs`, executed as a separate host-side process. |
| Linux kernel (via libkrunfw) | GPL-2.0 | `github.com/nohajc/libkrunfw` | Prebuilt guest kernel image and modules in `vendor/kernel/`. Runs as the boot kernel inside the guest microVM. |
| [libkrun](https://github.com/containers/libkrun) | Apache-2.0 | `github.com/containers/libkrun` | Dependency of `anylinuxfs`, providing the hypervisor runtime. |
| [vmnet-helper](https://github.com/nirs/vmnet-helper) | Apache-2.0 | `github.com/nirs/vmnet-helper` | Prebuilt helper to bring up host-only vmnet bridge. |
| [gvproxy](https://github.com/containers/gvisor-tap-vsock) | Apache-2.0 | `github.com/containers/gvisor-tap-vsock` | Built from source into `vendor/bin/gvproxy`, executed as a host-side process for guest network proxying. |
| Alpine Linux rootfs base | Mixed | Docker Hub `library/alpine` | Verified minimal container environment for guest userland tools. |


## Architecture & Isolation

- `anylinuxfs`, `gvproxy`, and `vmnet-helper` are separate executables invoked by
  THLNTFS via process execution — no shared address space, no
  static or dynamic linking against THLNTFS's own proprietary binaries.
- The Linux kernel and guest tools run inside an isolated libkrun microVM — an entirely
  separate virtual machine context from the macOS host process.

