#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

echo "Starting user_data setup for AI Inference Endpoint"

# Ensure docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Docker not found, installing..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io
fi

systemctl enable docker
systemctl start docker

# Install and Configure NVIDIA Container Toolkit so Docker can use the GPU
if ! command -v nvidia-ctk &> /dev/null; then
    echo "Installing nvidia-container-toolkit..."
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    apt-get update
    apt-get install -y nvidia-container-toolkit
fi

nvidia-ctk runtime configure --runtime=docker
systemctl restart docker

# Pull the vLLM image
docker pull vllm/vllm-openai:gemma4

export HF_TOKEN="${hf_token}"
MODEL="${model_id}"

# Run vLLM with OpenAI compatible server
docker run -d --name vllm \
  --runtime nvidia --gpus all \
  --restart unless-stopped \
  -e HF_TOKEN=$HF_TOKEN \
  -v /opt/huggingface:/root/.cache/huggingface \
  -p 8000:8000 \
  --ipc=host \
  vllm/vllm-openai:gemma4 \
  --model $MODEL \
  --max-model-len 2048 \
  --gpu-memory-utilization 0.90 \
  --host 0.0.0.0

echo "vLLM container started with model $MODEL"
