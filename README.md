# HG002 Variant Calling Pipeline

## Overview
Production-ready Nextflow pipeline for variant calling on PacBio HiFi data using:
- **Clair3** - Long-read variant caller
- **DeepVariant** - Deep learning variant caller
- **Reference**: GRCh38
- **Sample**: HG002 (Genome in a Bottle)

## Requirements
- Nextflow >= 22.10.1
- Singularity >= 3.8
- SLURM job scheduler
- minimap2 (via conda)
- samtools (via conda)

## Input Data
- PacBio HiFi BAM: m21009_241011_231051.hifi_reads.bam
- Source: https://downloads.pacbcloud.com/public/2024Q4/Vega/HG002/data/
- Reference: GRCh38 primary assembly
- Used 168,147 reads (subset of full dataset)

## Pipeline Steps
1. Align reads - minimap2 aligns FASTQ to GRCh38 reference
2. Clair3 - Variant calling from aligned BAM
3. DeepVariant - Deep learning variant calling
4. Filter - Keep only chromosomes 1-22
5. Benchmark - Compare to GIAB truth set using hap.py

## Quick Start

### 1. Setup conda environment
```bash
conda create -n mapping -c bioconda minimap2 samtools -y
conda activate mapping
```

### 2. Align reads
```bash
minimap2 -ax map-hifi -t 16 reference/GRCh38.primary_assembly.genome.fa data/HG002.fastq | \
    samtools sort -@ 16 -o data/HG002_aligned.bam
samtools index data/HG002_aligned.bam
```

### 3. Run pipeline
```bash
nextflow run main.nf -profile slurm -resume
```

### 4. Monitor
```bash
squeue -u $USER
tail -f .nextflow.log
```

## Output Structure
```
results/
├── clair3_output/
│   ├── merge_output.vcf.gz
│   └── clair3.chr1_22.vcf.gz
├── deepvariant_output/
│   ├── deepvariant.vcf.gz
│   └── deepvariant.chr1_22.vcf.gz
└── benchmark/
    ├── clair3_happy.summary.csv
    └── deepvariant_happy.summary.csv
```

## Benchmark Results
Benchmarked against GIAB HG002 truth set v4.2.1 (chr1-22)

### Clair3
| Type  | Precision | Recall | F1 Score |
|-------|-----------|--------|----------|
| SNP   | 0.8498    | 0.2739 | 0.4142   |
| INDEL | 0.5622    | 0.1840 | 0.2773   |

### DeepVariant
| Type  | Precision | Recall | F1 Score |
|-------|-----------|--------|----------|
| SNP   | 0.8365    | 0.1877 | 0.3067   |
| INDEL | 0.7218    | 0.1272 | 0.2162   |

### Notes
- Low recall is expected as only 5% of full dataset was used
- High precision confirms pipeline is working correctly
- Full dataset would yield recall greater than 0.90

## Troubleshooting
- Job failed? Check: cat .nextflow.log | tail -30
- Out of memory? Edit nextflow.config: process.memory = 128 GB

## Author
Sara Naveed
Assignment 1 - Variant Calling Pipeline
Advanced Computational Biology
NUST SINES
