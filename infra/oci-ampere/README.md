# `oci-ampere` — Oracle Cloud Ampere A1 host for arm64 captures

Terraform module that provisions a single Always-Free Ampere A1 Flex instance (Ubuntu 24.04 LTS, aarch64) and bootstraps Phoronix Test Suite on it. The host gives [LinuxBenchHub](../../) an aarch64 column the GitHub Actions x86 runners can't produce, at $0/month.

## What it builds

```text
┌──────────────────────────────────────────┐
│ Region: <var.region>                     │
│ Compartment: <var.compartment_ocid>      │
│                                          │
│  ┌────────────────────────────────────┐  │
│  │ VCN 10.0.0.0/16                    │  │
│  │  ├─ Internet Gateway               │  │
│  │  ├─ Default route → IGW            │  │
│  │  └─ Subnet 10.0.1.0/24 (public)    │  │
│  │      └─ Security list: SSH 22 only │  │
│  │          from ssh_ingress_cidr     │  │
│  └────────────────────────────────────┘  │
│                                          │
│  Ampere A1 Flex — 4 OCPU / 24 GB / 50 GB │
│  Ubuntu 24.04 LTS aarch64                │
│  cloud-init: PTS + R + Docker            │
└──────────────────────────────────────────┘
```

All inside Oracle Cloud's Always-Free quota (4 OCPUs + 24 GB + 200 GB block storage per region, indefinite).

## Prerequisites

1. **Oracle Cloud account.** Sign up at [signup.oraclecloud.com](https://signup.oraclecloud.com). Requires a credit card for identity verification but the Always-Free tier doesn't bill against it.
2. **`oci`CLI configured.**`brew install oci-cli`then`oci setup config`— this generates the API signing key and writes`~/.oci/config` with the five values Terraform needs (`tenancy_ocid`, `user_ocid`, `fingerprint`, `private_key_path`, `region`). Upload the generated public key under Console → Identity → Users → *your user* → API Keys.
3. **OpenTofu ≥ 1.6** (or Terraform ≥ 1.6 if you prefer the BSL CLI). `brew install opentofu`. Commands below use `tofu`; substitute `terraform` if you're on the HashiCorp CLI.
4. **An SSH keypair.** `ssh-keygen -t ed25519 -f ~/.ssh/lbh-ampere` if you want one dedicated to this host.

## Provisioning

```bash
cd infra/oci-ampere
cp terraform.tfvars.example terraform.tfvars

# Fill in the five OCI values, your SSH public key, and narrow ssh_ingress_cidr

# to your current IP (`curl ifconfig.me` → append /32)

tofu init
tofu plan    # review — should be ~7 resources to add, $0 monthly cost
tofu apply
```

`apply`finishes in 60–90 seconds. cloud-init then runs for another 3–5 minutes installing PTS, R, and build dependencies in the background. SSH will start working once the instance has a public IP, but`lbh-capture`won't be available until cloud-init finishes —`cloud-init status --wait` on the host blocks until it's done.

```bash

# OpenTofu prints the SSH command in its outputs

tofu output ssh_command

# → ssh ubuntu@<public-ip>

ssh ubuntu@<public-ip>
cloud-init status --wait    # blocks until bootstrap finishes (or fails loudly)
/usr/local/bin/lbh-capture  # run as ubuntu, NOT sudo — the user-config.xml is in ~ubuntu/

# → /home/ubuntu/platform/build/linux-bench-hub/captures/composite-2026-05-28.xml

```

## Tearing it down

```bash
tofu destroy
```

Removes every resource the module created. Useful when Oracle's free-tier capacity-reclaim sweeps idle Ampere instances (they will reclaim a VM that's been at <20% CPU for several weeks); easier to `destroy`+`apply` fresh than to argue with their reclamation policy. The OpenTofu state captures the image OCID used so the rebuilt VM matches.

## Known issues

- **"Out of host capacity" on `apply`.** Oracle's Always-Free Ampere capacity is genuinely scarce in popular regions (us-ashburn-1, us-phoenix-1). Workarounds: try a different availability domain by editing `main.tf`(the`index = 0`line on`availability_domains`), retry on a different day, or pick a less-popular region at signup (uk-london-1, ap-tokyo-1 tend to have headroom).
- **cloud-init doesn't re-run on `apply`.** Editing `cloud-init.yml`and re-applying does *not* re-bootstrap the existing instance — cloud-init only runs on first boot. Either`terraform destroy && terraform apply` to rebuild, or SSH in and run the relevant commands manually.
- **Free-tier reclamation.** Idle Ampere VMs get reclaimed after a few weeks of low CPU. The monthly capture cron will exercise the CPU enough to keep it alive, but a long pause in captures (or a code freeze) can lose the host. `terraform apply` rebuilds it identically.

## How the GitHub Action uses this

`.github/workflows/capture-benchmarks.yml`'s `capture-ampere-arm64`job stores`OCI_AMPERE_HOST`(IP) and`OCI_AMPERE_SSH_KEY`(private key PEM) as repo secrets, then runs a`[ubuntu, fedora, debian]`matrix against this one host — same images, same`pkg_install`lists, and the same`.github/scripts/container-capture.sh`body the x86 legs run inside GitHub's native`container:`, just driven remotely instead of locally:

```bash
scp pkg-install.sh container-capture.sh pts-batch-config.xml \
  ubuntu@$OCI_AMPERE_HOST:/home/ubuntu/platform/build/linux-bench-hub/runner/<distro>/
ssh ubuntu@$OCI_AMPERE_HOST "docker run --rm \
  -v /home/ubuntu/platform/build/linux-bench-hub/runner/<distro>/pkg-install.sh:/pkg-install.sh:ro \
  -v /home/ubuntu/platform/build/linux-bench-hub/runner/<distro>/container-capture.sh:/container-capture.sh:ro \
  -v /home/ubuntu/platform/build/linux-bench-hub/runner/<distro>/pts-batch-config.xml:/pts-batch-config.xml:ro \
  -v /home/ubuntu/platform/build/linux-bench-hub/captures/<distro>:/output \
  <image> bash -c 'bash /pkg-install.sh && bash /container-capture.sh'"
scp ubuntu@$OCI_AMPERE_HOST:/home/ubuntu/platform/build/linux-bench-hub/captures/<distro>/composite.xml \
  benchmarks/<distro>-arm64/composite-latest.xml
```

Only the `ubuntu` row still has a bare-host fallback (`/usr/local/bin/lbh-capture`, installed via `runcmd` above) for ad-hoc manual runs — CI itself always goes through Docker for all three distros, so the x86 and arm64 numbers for a given distro come from the same install steps and the same PTS config, differing only in CPU architecture.

Still open: the R parser + Next.js site (`site/lib/benchmarks.ts`) only know about the three x86 `distros`today and don't render an`arch` dimension yet — the arm64 composite XML is captured and committed, but nothing displays it. Tracked as a follow-up.
