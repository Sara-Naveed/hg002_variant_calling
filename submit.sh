#!/bin/bash

#SBATCH --job-name=variant_calling
#SBATCH --partition=gpu
#SBATCH --nodes=1
#SBATCH --cpus-per-task=16
#SBATCH --mem=64GB
#SBATCH --time=48:00:00
#SBATCH --output=logs/slurm_%j.log
#SBATCH --error=logs/slurm_%j.err

set -e

echo "Starting Variant Calling Pipeline..."
echo "Job ID: $SLURM_JOB_ID"
echo "Started at: $(date)"

mkdir -p logs results work reports

nextflow run main.nf \
    -profile slurm \
    -resume \
    -with-report reports/execution_report.html \
    -with-timeline reports/timeline.html

echo "Pipeline completed at: $(date)"
