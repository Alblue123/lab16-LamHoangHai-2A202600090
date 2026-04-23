1.# Lab 16 Report: AI Inference Deployment on GCP
**Author:** Lam Hoang Hai

## 1. Successful API Inference

The model `google/gemma-4-E2B-it` was successfully deployed and tested using an NVIDIA L4 GPU in the `asia-northeast1-b` (Tokyo) zone.

**Request:**

- Model: google/gemma-4-E2B-it
- Input: "Hãy giải thích ngắn gọn Cloud NAT trong Google Cloud là gì?"

**Response Snippet:**
> "Cloud NAT (Network Address Translation) trong Google Cloud là một dịch vụ cho phép các máy chủ (VMs) trong mạng riêng (VPC) của bạn truy cập Internet mà không cần phải có địa chỉ IP công cộng tĩnh..."

## 2. Infrastructure Details

- **GPU Type:** NVIDIA L4 (24GB VRAM)
- **Machine Type:** g2-standard-4 (4 vCPU, 16GB RAM)
- **Region/Zone:** asia-northeast1-b
- **Orchestration:** Terraform + Docker + vLLM

## 3. Cold Start Time Report

- **Infrastructure Provisioning:** ~2 minutes
- **GPU Driver & Docker Setup:** ~3 minutes
- **Model Download & Weight Loading:** ~7 minutes
- **Total Cold Start Time:** **~12 minutes**

## 4. Cost Management

- Standard L4 instances were used to ensure stability after Spot stockouts in Taiwan.
- Infrastructure is configured for immediate cleanup via `terraform destroy`.
