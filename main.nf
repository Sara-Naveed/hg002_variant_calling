#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

params.bam_file = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/data/HG002_aligned.bam"
params.bai_file = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/data/HG002_aligned.bam.bai"
params.ref_genome = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/reference/GRCh38.primary_assembly.genome.fa"
params.ref_fai = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/reference/GRCh38.primary_assembly.genome.fa.fai"
params.outdir = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/results"
params.truth_vcf = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark.vcf.gz"
params.truth_bed = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/benchmark/HG002_GRCh38_1_22_v4.2.1_benchmark_noinconsistent.bed"
params.clair3_sif = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/reference/Clair3.sif"
params.deepvariant_sif = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/reference/DeepVariant.sif"
params.happy_sif = "/hdd4/sines/advancedcomputationalbiology/sara.sines/hg002_variant_project/benchmark/hap.py_latest.sif"

process clair3_calling {
    cpus 16
    memory '64 GB'

    input:
    path bam
    path bai
    path ref
    path ref_fai

    output:
    path "clair3_output/merge_output.vcf.gz", emit: vcf
    path "clair3_output/merge_output.vcf.gz.tbi", emit: tbi

    script:
    """
    singularity exec ${params.clair3_sif} run_clair3.sh \
        --bam_fn=${bam} \
        --ref_fn=${ref} \
        --threads=${task.cpus} \
        --platform=hifi \
        --model_path=/opt/models/hifi \
        --output=clair3_output \
        --include_all_ctgs
    """
}

process deepvariant_calling {
    cpus 16
    memory '64 GB'

    input:
    path bam
    path bai
    path ref
    path ref_fai

    output:
    path "deepvariant.vcf.gz", emit: vcf

    script:
    """
    singularity exec ${params.deepvariant_sif} /opt/deepvariant/bin/run_deepvariant \
        --model_type=PACBIO \
        --ref=${ref} \
        --reads=${bam} \
        --output_vcf=deepvariant.vcf.gz \
        --num_shards=${task.cpus}
    """
}

process filter_clair3 {
    cpus 4
    memory '16 GB'

    input:
    path vcf

    output:
    path "clair3.chr1_22.vcf.gz", emit: filtered_vcf
    path "clair3.chr1_22.vcf.gz.tbi", emit: filtered_tbi

    script:
    """
    singularity exec ${params.clair3_sif} bcftools view \
        -r chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22 \
        ${vcf} -Oz -o clair3.chr1_22.vcf.gz
    singularity exec ${params.clair3_sif} bcftools index -t clair3.chr1_22.vcf.gz
    """
}

process filter_deepvariant {
    cpus 4
    memory '16 GB'

    input:
    path vcf

    output:
    path "deepvariant.chr1_22.vcf.gz", emit: filtered_vcf
    path "deepvariant.chr1_22.vcf.gz.tbi", emit: filtered_tbi

    script:
    """
    singularity exec ${params.clair3_sif} bcftools view \
        -r chr1,chr2,chr3,chr4,chr5,chr6,chr7,chr8,chr9,chr10,chr11,chr12,chr13,chr14,chr15,chr16,chr17,chr18,chr19,chr20,chr21,chr22 \
        ${vcf} -Oz -o deepvariant.chr1_22.vcf.gz
    singularity exec ${params.clair3_sif} bcftools index -t deepvariant.chr1_22.vcf.gz
    """
}

process benchmark_clair3 {
    cpus 8
    memory '32 GB'

    input:
    path query_vcf
    path query_tbi
    path truth_vcf
    path truth_bed
    path ref
    path ref_fai

    output:
    path "clair3_happy.*", emit: results

    script:
    """
    singularity exec ${params.happy_sif} hap.py ${truth_vcf} ${query_vcf} \
        -f ${truth_bed} \
        -r ${ref} \
        -o clair3_happy \
        --engine=vcfeval \
        --threads=${task.cpus}
    """
}

process benchmark_deepvariant {
    cpus 8
    memory '32 GB'

    input:
    path query_vcf
    path query_tbi
    path truth_vcf
    path truth_bed
    path ref
    path ref_fai

    output:
    path "deepvariant_happy.*", emit: results

    script:
    """
    singularity exec ${params.happy_sif} hap.py ${truth_vcf} ${query_vcf} \
        -f ${truth_bed} \
        -r ${ref} \
        -o deepvariant_happy \
        --engine=vcfeval \
        --threads=${task.cpus}
    """
}

workflow {
    bam       = Channel.fromPath(params.bam_file)
    bai       = Channel.fromPath(params.bai_file)
    ref       = Channel.fromPath(params.ref_genome)
    ref_fai   = Channel.fromPath(params.ref_fai)
    truth_vcf = Channel.fromPath(params.truth_vcf)
    truth_bed = Channel.fromPath(params.truth_bed)

    clair3_vcf      = clair3_calling(bam, bai, ref, ref_fai)
    deepvariant_vcf = deepvariant_calling(bam, bai, ref, ref_fai)

    clair3_filtered = filter_clair3(clair3_vcf.vcf)
    dv_filtered     = filter_deepvariant(deepvariant_vcf.vcf)

    benchmark_clair3(clair3_filtered.filtered_vcf, clair3_filtered.filtered_tbi, truth_vcf, truth_bed, ref, ref_fai)
    benchmark_deepvariant(dv_filtered.filtered_vcf, dv_filtered.filtered_tbi, truth_vcf, truth_bed, ref, ref_fai)
}
