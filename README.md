# Qubic Devkit

This repository contains the Qubic Devkit, designed to help developers set up a Qubic testnet node and run the HM25 Smart Contract (SC) demo for the Hackathon Madrid 2025. Follow the steps below to get started.

## Important Notes

* Optimized for Demo Branch:
  This devkit is tailored for the madrid-2025 branch of the Qubic core repository (https://github.com/qubic/core/tree/madrid-2025). It includes the HM25 Smart Contract demo and works best with this setup.

* Custom Smart Contracts:
  If you want to use your own Smart Contract (SC), start from the main Qubic core repository (https://github.com/qubic/core). You will also need to:
  * Modify qubic-cli and the frontend to suit your SC. The qubic-cli will become your UI in command line, and it is a quick way to test your SC code in core. 
  * Adjust the launch scripts (e.g., deploy.sh) as necessary.

---

## Summary of Commands

1. Environment Setup (only run once):
```bash
sudo ./environment_setup.sh
```
2. Deploy the Node and Demo:

```bash
./deploy.sh /root/qubic/Qubic.efi
```


For step-by-step in more details, please see below.

## Step 1: Set Up the Environment

---

To begin, you need to set up the development environment on your machine. This step only needs to be run once.

* Run the Environment Setup Script:

  Execute the environment_setup.sh script to install dependencies and clone the necessary repositories and build them all.
  ```bash
  sudo ./environment_setup.sh
  ```
  This script will also download the qubic.vhd from [https://files.qubic.world/qubic-vde.zip](https://files.qubic.world/qubic-vde.zip) for you. 

## Step 2: Deploy the Qubic Node and HM25 Demo

---
Given the [pre-compiled EFI file](./Qubic.efi) (which is built upon [this branch](https://github.com/qubic/core/tree/madrid-2025) in core), deploy the Qubic testnet node and the HM25 demo using the deploy.sh script. 
For a custom build of the EFI file for Qubic testnet, please refer to [Kavatak's guide here](https://github.com/KavataK/QubicNetworkDeploymentGuide).
* Run the Deployment Script:
  For this demo, use the following command:
  ```bash
  ./deploy.sh /root/qubic/Qubic.efi
  ```
  This script will:
  * Prepare the qubic.vhd with epoch 152 for you using the zip file Ep152.zip attached in this repo.
  * Launch the Qubic testnet node and the HM25 Smart Contract.
  * Start the RPC services (qubic-node, qubic-http, and qubic go-archive).
  * Launch the HM25 demo frontend example.
