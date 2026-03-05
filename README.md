# PVE Manager

Terminal UI for bulk managing Proxmox VMs.

## Features

- Bulk VM operations
- dialog TUI
- color status indicators
- node-aware
- template detection

## Screenshot


## Installation

### NixOS

nix-shell -p dialog jq

### Debian / Ubuntu

sudo apt install dialog jq

### Install script

```bash
git clone https://github.com/gallbotond/pve-manager
cd pve-manager
chmod +x bin/pve-manager
```

## Configuration

Copy the example config:

cp config/proxmox.env.example ~/.config/pve-manager/proxmox.env

Edit:

```bash
API_URL=
TOKEN_ID=
TOKEN_SECRET=
```

## Usage

pve-manager

## Operations Supported

- shutdown
- stop
- suspend
- delete

## Security

Uses Proxmox API tokens.

## License

MIT