# Remote Development with VS Code and Akash Network

This guide provides detailed instructions for setting up a remote development environment using Visual Studio Code (VS Code) with the Remote - SSH extension and deploying a containerized development environment on the Akash Network. The setup enables Node.js development in a remote container without requiring source code on your local machine.

## Overview

VS Code Remote Development allows you to use containers, remote machines, or Windows Subsystem for Linux (WSL) as full-featured development environments. This guide focuses on using the **Remote - SSH** extension to connect to a remote container deployed on the Akash Network, a decentralized cloud platform.

### Key Components

- **VS Code Remote - SSH**: Connects to a remote machine/container via SSH, allowing you to work on remote folders as if they were local. The VS Code Server is installed on the remote machine to handle communication and extension execution.
- **Akash Network**: A decentralized cloud platform for deploying containerized applications.
- **Docker**: Used to build and push the container image for the remote development environment.
- **Node.js Development**: The provided Docker image (`okn2015/ssh-cloudflared`) supports Node.js development in the remote container.

## Prerequisites

Before starting, ensure you have the following:

- **VS Code** installed on your local machine.
- **Akash Network CLI** and an account set up on the Akash Network.
- **Docker** installed locally for building and pushing images.
- A terminal for SSH and command-line operations.
- Basic familiarity with SSH key management and Docker.

## Setup Instructions

### Step 1: Install VS Code Extensions

Install the required VS Code extensions to enable remote development:

1. Open VS Code.
2. Go to the Extensions view (`Ctrl+Shift+X` or `Cmd+Shift+X` on macOS).
3. Search for and install the following extensions by Microsoft:
   - **Remote - SSH**
   - **Remote Development** (this is an extension pack that includes Remote - SSH and other remote development tools).

### Step 2: Generate SSH Key Pair

To securely connect to the remote container, generate an SSH key pair:

1. Open a terminal on your local machine.
2. Run the following command to create an SSH key pair:
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   ```
   - Press `Enter` to accept the default file location (`~/.ssh/id_ed25519`).
   - Optionally, set a passphrase for added security.
3. Copy the public key to use in the Akash deployment configuration:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
   Save the output (public key) for the next step.

### Step 3: Configure `akash.yml`

The `akash.yml` file defines the deployment configuration for the Akash Network. Update it with your SSH public key.

1. Open or create the `akash.yml` file in your project directory.
2. Add your SSH public key to the configuration. Example:
   ```yaml
   ---
   version: '2.0'
   services:
     remote-development:
       image: okn2015/ssh-cloudflared:latest
       env:
         - PUBLIC_KEY=ssh-ed25519 AAAA... your_email@example.com
       expose:
         - port: 30898
           as: 22
           to:
             - global: true
   profiles:
     compute:
       remote-development:
         resources:
           cpu:
             units: 1
           memory:
             size: 2Gi
           storage:
             size: 10Gi
     placement:
       akash:
         pricing:
           remote-development:
             denom: uakt
             amount: 1000
   deployment:
     remote-development:
       akash:
         profile: remote-development
         count: 1
   ```
3. Replace `PUBLIC_KEY` with the public key copied in Step 2.

### Step 4: Deploy the Container on Akash Network

Deploy the configured container to the Akash Network:

1. Open a terminal and navigate to the directory containing `akash.yml`.
2. Deploy the configuration using the Akash CLI:
   ```bash
   akash deploy akash.yml
   ```
3. Access the **Akash Console** (web interface) to monitor the deployment.
   - Check the **Events** and **Logs** tabs to verify successful deployment.
   - Access the **Shell** environment in the Akash Console to confirm the container is running.
4. Note the **provider's host domain name** and **port number** (e.g., `30898`) assigned to your deployment, as these will be used for SSH access.

### Step 5: SSH into the Remote Container

Connect to the deployed container from your local machine:

1. Use the SSH command, adjusting the private key path, username, provider address, and port:
   ```bash
   ssh -i ~/.ssh/id_ed25519 developer@<akash-provider-address> -p 30898
   ```
   - Replace `<akash-provider-address>` with the provider's host domain name from the Akash Console.
   - Replace `30898` with the port number provided by the Akash Console.
2. Verify that you can successfully log in to the remote container.

### Step 6: Configure SSH for Easy Access

To simplify SSH connections, configure the `~/.ssh/config` file on your local machine:

1. Open or create the `~/.ssh/config` file:
   ```bash
   nano ~/.ssh/config
   ```
2. Add the following configuration, adjusting the values as needed:
   ```text
   Host akash_remote_dev
     User developer
     HostName <akash-provider-address>
     IdentityFile ~/.ssh/id_ed25519
     Port 30898
     ForwardAgent yes
   ```
   - Replace `<akash-provider-address>` with the provider's host domain name.
   - Replace `30898` with the port number from the Akash Console.
   - Ensure `IdentityFile` points to your private key.
3. Save and exit the file.
4. Test the configuration:
   ```bash
   ssh akash_remote_dev
   ```
   You should connect to the remote container without manually specifying the key, user, or port.

### Step 7: Connect VS Code to the Remote Container

1. Open VS Code.
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on macOS) to open the Command Palette.
3. Select **Remote-SSH: Connect to Host**.
4. Choose `akash_remote_dev` from the list (based on the SSH config).
5. VS Code will install the VS Code Server on the remote container and connect. You can now open and work on folders in the remote environment.

### Step 8: Update or Redeploy the Docker Image

If you modify the Docker image or deployment configuration, you must rebuild and push the updated image to Docker Hub, as Akash caches images.

1. **Build and Push the Docker Image**:
   - Navigate to the directory containing your `Dockerfile`.
   - Run the following command to build and push the image (update the version tag to avoid caching issues):
     ```bash
     docker buildx build \
       --no-cache \
       --platform linux/amd64,linux/arm64 \
       -t <your-dockerhub-username>/ssh-cloudflared:<version> \
       . \
       --push
     ```
     - Replace `<your-dockerhub-username>` with your Docker Hub username.
     - Replace `<version>` with a new version tag (e.g., `v1.0.1`).
2. Update the `image` field in `akash.yml` to match the new image tag:
   ```yaml
   services:
     remote-development:
       image: <your-dockerhub-username>/ssh-cloudflared:<version>
   ```
3. Redeploy the updated `akash.yml`:
   ```bash
   akash deploy akash.yml
   ```
4. If you encounter SSH connection issues after redeployment (e.g., due to a new provider address), remove the old provider's entry from `~/.ssh/known_hosts`:
   ```bash
   ssh-keygen -R <old-akash-provider-address>
   ```
   - Replace `<old-akash-provider-address>` with the previous provider's host domain name.

### Step 9: Troubleshooting

- **SSH Connection Fails**: Verify the provider address, port, and private key path. Ensure the public key is correctly set in `akash.yml`.
- **VS Code Server Installation Fails**: Ensure the remote container has internet access and sufficient resources (CPU, memory, storage).
- **Akash Deployment Fails**: Check the **Events** and **Logs** tabs in the Akash Console for errors. Verify the `akash.yml` syntax and resource requirements.
- **Cached Image Issues**: Always increment the Docker image version tag when redeploying to avoid Akash using a cached version.

## Additional Notes

- The provided Docker image (`okn2015/ssh-cloudflared:latest`) is preconfigured for Node.js development. If you customize the image, ensure it includes:
  - An SSH server (e.g., OpenSSH).
  - Node.js and necessary development tools.
  - The public key for SSH access.
- For more details on the deployment configuration, refer to the `akash.yml` file.
- Always use a unique version tag for Docker images to prevent caching issues on Akash.
- For further information on Akash Network, visit the [Akash Documentation](https://docs.akash.network/).
- For VS Code Remote Development, refer to the [VS Code Remote Documentation](https://code.visualstudio.com/docs/remote/remote-overview).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
