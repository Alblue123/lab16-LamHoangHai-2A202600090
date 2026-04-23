variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "hf_token" {
  description = "Hugging Face Token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "GCP Region"
  type        = string
  default     = "asia-northeast1"
}

variable "zone" {
  description = "GCP Zone"
  type        = string
  default     = "asia-northeast1-b"
}

variable "model_id" {
  description = "Model ID to load"
  type        = string
  default     = "google/gemma-4-E2B-it"
}
