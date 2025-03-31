# Qubic Devkit - Hackathon Madrid 2025 Demo

This repository contains the Qubic Devkit, designed to help developers set up a Qubic testnet node and run the HM25 Smart Contract (SC) demo for the Hackathon Madrid 2025. Follow the steps below to get started.

## Important Notes

* Optimized for Demo Branch:
  This devkit is tailored for the madrid-2025 branch of the Qubic core repository (https://github.com/qubic/core/tree/madrid-2025). It includes the HM25 Smart Contract demo and works best with this setup.

* Custom Smart Contracts:
  If you want to use your own Smart Contract (SC), start from the main Qubic core repository (https://github.com/qubic/core). You will need to:
  * Modify qubic-cli and the frontend to suit your SC.
  * Adjust the launch scripts (e.g., deploy.sh) as necessary.

---

## Summary of Commands

1. Environment Setup (only run once):
```bash
sudo ./environment_setup.sh https://github.com/qubic/qubic-cli/tree/madrid-2025
```
2. Navigate and Build EFI:
   
After preparing the seeds.txt, peers.txt, and config.yaml:
```bash
cd /root/qubic/qubic_docker
./efi_build.sh https://github.com/qubic/core/tree/madrid-2025
```
3. Deploy the Node and Demo:

After preparing the qubic.vhd and put them in `/root/qubic/qubic.vhd`:
```bash
./deploy.sh https://github.com/qubic/core/tree/madrid-2025 /root/qubic/qubic-efi-cross-build/Qubic.efi
```

For step-by-step in more details, please see below.

## Step 1: Set Up the Environment


To begin, you need to set up the development environment on your machine. This step only needs to be run once.

* Run the Environment Setup Script:

  Execute the environment_setup.sh script to install dependencies and clone the necessary repositories. Be sure to provide the qubic-cli branch URL for the HM25 SC demo.
  ```bash
  sudo ./environment_setup.sh https://github.com/qubic/qubic-cli/tree/madrid-2025
  ```

  This ensures the correct version of qubic-cli is installed to support the HM25 Smart Contract demo.

## Step 2: Prepare Configuration Files

Next, prepare the configuration files required for building the EFI file.

1. Navigate to the Docker Directory:

```bash
cd /root/qubic/qubic_docker
```

2. Create Configuration Files:

Prepare the following files as instructed in the [qubic-efi-cross-build](https://github.com/icyblob/qubic-efi-cross-build/tree/main) repository:
* seeds.txt
* peers.txt
* config.yaml

Refer to the repository for specific details on how to configure these files correctly.

## Step 3: Build the EFI File

To simplify the EFI build process, use the provided efi_build.sh script.
* Run the EFI Build Script:
  Provide the GitHub branch URL for the Qubic core repository. For this demo, use the madrid-2025 branch.

  ```bash
  ./efi_build.sh https://github.com/qubic/core/tree/madrid-2025
  ```

  This script will compile the Qubic.efi file based on the specified branch and your configuration files.

## Step 4: Prepare the Qubic.vhd and epoch files
Please download the qubic.vhd file [here](https://files.qubic.world/qubic-vde.zip) and put it to `/root/qubic/qubic.vhd`. The epoch unzipped files should be put in `/root/filesForVHD`. Please refer to [this Discord channel](https://discord.com/channels/768887649540243497/768890555564163092) to download the epoch zip files.

## Step 5: Deploy the Qubic Node and HM25 Demo
After compiling the EFI file, deploy the Qubic testnet node and the HM25 demo using the deploy.sh script.
* Run the Deployment Script:
  Provide the GitHub branch URL and the path to the compiled EFI file. For this demo, use the following command:
  ```bash
  ./deploy.sh https://github.com/qubic/core/tree/madrid-2025 /root/qubic/qubic-efi-cross-build/Qubic.efi
  ```
  This script will:
  * Launch the Qubic testnet node and the HM25 Smart Contract.
  * Start the RPC services (qubic-node, qubic-http, and qubic go-archive).
  * Launch the HM25 demo frontend example.
 






