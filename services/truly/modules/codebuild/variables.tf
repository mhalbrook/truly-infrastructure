################################################################################
# Global Variables
################################################################################
variable "environment" {
  description = "environment that the nlb will support. Valid options are 'cit', 'uat', 'prod', 'core' or 'campus'"
  type        = string
}

variable "project" {
  description = "Name of the Volly Project the infrastructure supports"
  type        = string
}

variable "service_name" {
  description = "Name of the service being built by the CodeBuild Project"
  type        = string
}

variable "tags" {
  description = "A mapping of tags to assign to all resources."
  type        = map(any)
  default     = {}
}

variable "default_tags" {
  description = "map of tags to be used on all resources created by the module"
  type        = map(any)
  default = {
    builtby = "terraform"
  }
}


################################################################################
# CodeBuild Project Variables
################################################################################
variable "kms_key_arn" {
  description = "The KMS Key to be used for encrypting the build project's build output artifacts."
  type        = string
}

#############################################################
# Source
#############################################################
variable "source_provider" {
  description = "Provider of the source repository. Valid options are 'Amazon S3', 'AWS CodeCommit', 'GitHub'. Bitbucket', or 'Github Enterprise'"
  type = string
  default = "BITBUCKET"
}

variable "source_location" {
  description = "The location of the source code from git or s3"
  type        = string
  default     = null
}

variable "source_version" {
  description = "The git branch of the source code to pull when building"
  type        = string
  default     = null
}

variable "image_id" {
  description = "The image identifier of the Docker image to use for this build project."
  type        = string
  default     = "aws/codebuild/amazonlinux2-x86_64-standard:3.0"
}

variable "privileged_mode" {
  description = "Sets whether to running the build command with elevated privileges."
  type        = bool
  default     = true
}

variable "build_timeout" {
  description = "The amount of time, in minutes, to wait until timing out any related build that does not get marked as completed."
  type        = string
  default     = 60
}

#############################################################
# Environment
#############################################################
variable "buildspec" {
  description = "The script that informs CodeBuild on how to perform the build"
  type        = string
  default     = null
}

variable "environment_variables" {
  description = "Map of additional environment variables to provising in the CodeBuild project"
  type        = map(any)
  default     = {}
}

variable "environment_type" {
  description = "The type of build environment to use for related builds."
  type        = string
  default     = "LINUX_CONTAINER"
}

variable "compute_type" {
  description = "Information about the compute resources the build project will use."
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

#############################################################
# Artifacts
#############################################################
variable "artifacts_type" {
  description = "Type of artifacts to output from CodeBuild. Valid options are 'NO ARTIFACTS', 'S3', or 'CODEPIPELINE'."
  type        = string
  default     = "NO_ARTIFACTS"
}

variable "artifacts_location" {
  description = "S3 Path to which Artifacts are stored."
  type        = string
  default     = null
}

variable "artifacts_namespace" {
  description = "The namespace to include in the path to which Artifacts are stored. Valid options are 'BUILD_ID' or 'NONE'."
  type        = string
  default     = "NONE"
}

variable "artifacts_override_name" {
  description = "Sets whether to allow the CodeBuild BuildSpec set the location and/or name of the Artifact package."
  type        = bool
  default     = false
}

variable "artifacts_zip_package" {
  description = "Sets whether to zip the final Artifacts package before uploading to the specified location."
  type        = bool
  default     = true
}

#############################################################
# Cache
#############################################################
variable "cache_type" {
  description = "The type of storage that will be used for the AWS CodeBuild project cache."
  type        = string
  default     = "NO_CACHE"
}

variable "cache_modes" {
  description = "List of settings that AWS CodeBuild uses to store and reuse build dependencies."
  type        = list(any)
  default     = []
}

variable "cache_location" {
  description = "The S3 Bucket Name and/or Prefix where the AWS CodeBuild project stores cached resources."
  type        = string
  default     = null
}
