
/*
Rough draft of quant-seq fwd analysis pipeline for Cryptococcus neoformans H99
This was tested on two subsampled fastq.gz as test datasets
UPDATE - adjusted to run on the full data.
*/

/*
Define dataset-specific input parameters.
These still need documentation and flexibility.
To find where they are used, search the document for the name, 
e.g. "params.featurename" is used in the featureCounts call.
*/

params.adapters = 'AAAAAAAAAAAA'
params.index_dir = '../CryptoRNASeq2020_draft/input_annotation/index'
params.index_prefix = 'CNA3_hisat2'
params.mRNAgff = 'input_annotation/H99.mRNAonly.2018-12-03.gff'
params.input_fq_dir = '/homes/ewallac2/mount/datastore/wallace_rna/bigdata/fastq/EH_050221_Data'
params.output_dir = 'quantseqfwd_test_output'
params.featuretype = 'mRNA'
params.featurename = 'Name'
params.num_processes = 4


/*
Define the aligner index and feature file (gff)
*/

Channel
        .fromPath("${params.index_dir}/${params.index_prefix}.*.ht2",
                  checkIfExists: true)
        .collect().set { index_ht2_parts }

mRNAgff = Channel.fromPath(params.mRNAgff)


/*
Define the input read files in fastq.gz format
*/

input_fq = Channel
    .fromPath("${params.input_fq_dir}/*.fastq.gz")
    .map { file -> tuple(file.simpleName, file) }
    .into { input_fq_qc; input_fq_cut}

/*
Run FastQC to produce a quality control report for the input data for every sample
*/

process runFastQC{
    errorStrategy 'ignore'
    tag "${sample_id}"
    cpus { 2 }
    input:
        set sample_id, file(sample_fq) from input_fq_qc

    output:
        file("${sample_id}_fastqc/*.zip") into fastqc_files

    """
    mkdir ${sample_id}_fastqc
    fastqc --outdir ${sample_id}_fastqc \
    -t ${task.cpus} \
    ${sample_fq}
    """
}

/*
Run multiQC to collate single quality control report across all samples.
*/

process runMultiQC{
    tag { "multiQC" }
    publishDir "${params.output_dir}/qc_input", mode: 'copy', overwrite: false

    input:
        file('*') from fastqc_files.collect()

    output:
        file('multiqc_report.html')

    """
    multiqc .
    """
}

/*
Cut sequencing adapters from 3' end of gene
*/

process cutAdapters {
    errorStrategy 'ignore'
    tag "${sample_id}"
    input:
        set sample_id, file(sample_fq) from input_fq_cut
    output:
        tuple val(sample_id), file("trim.fq") into cut_fq
    shell:
        """
        cutadapt --trim-n -O 1 -m 5 -a ${params.adapters} \
            -o trim.fq ${sample_fq} -j ${params.num_processes}
        """
}

/*
Align trimmed reads to the genome with hisat2
*/

process alignHisat2 {
    errorStrategy 'ignore'
    tag "${sample_id}"
    input:
        set sample_id, file(sample_fq) from cut_fq
        file(index_ht2_parts) from index_ht2_parts
    output:
        file("unaligned.fq") into unaligned_fq
        tuple val(sample_id), file("aligned.sam") into aligned_sam
    shell:
        """
        hisat2 --version
        hisat2 -p ${params.num_processes} -k 2 \
            --no-spliced-alignment --rna-strandness F --no-unal \
            --un unaligned.fq -x ${params.index_prefix} \
            -S aligned.sam -U ${sample_fq} 
        """
}

/*
Turn unsorted aligned samfiles into sorted indexed compressed bamfiles
*/

process samViewSort {
    errorStrategy 'ignore'
    tag "${sample_id}"
    input:
        set val(sample_id), file(sample_sam) from aligned_sam
    output:
        tuple val(sample_id), file("aligned_sorted.bam"), \
            file("aligned_sorted.bam.bai") into aligned_sorted_bam
    shell:
        """
        samtools --version
        samtools view -b ${sample_sam} | samtools sort \
            -@ ${params.num_processes} -O bam -o aligned_sorted.bam -
        samtools index aligned_sorted.bam
        """
}

// Split channel for use in multiple downstream processes.
aligned_sorted_bam.into { bedgraph_bam; htscount_bam }

/*
Make bedgraphs showing coverage of aligned reads
*/

process makeBedgraphs {
    errorStrategy 'ignore'
    tag "${sample_id}"
    publishDir "${params.output_dir}/${sample_id}", mode: 'copy'
    input:
        tuple val(sample_id), file(sample_bam), file(sample_bam_bai) \
            from bedgraph_bam
    output:
        tuple file("plus.bedgraph.gz"), \
            file("minus.bedgraph.gz") into bedgraph
    shell:
        """
        bedtools --version
        bedtools genomecov -ibam ${sample_bam} -trackline -bga \
            -strand + | gzip > plus.bedgraph.gz
        bedtools genomecov -ibam ${sample_bam} -trackline -bga \
            -strand - | gzip > minus.bedgraph.gz
        """
}

/*
Run rename Bam files by sample, for input into featureCounts.
*/

process renameBamSample {
    errorStrategy 'ignore'
    tag "${sample_id}"
    input:
        tuple val(sample_id), file(sample_bam), file(sample_bam_bai) \
            from htscount_bam
    output:
        file("${sample_id}_aln.bam") into sampleid_aln_bam
    shell:
        """
        ln -s ${sample_bam} ${sample_id}_aln.bam
        """
}

/*
Run featureCounts to count aligned reads to genes for all processed samples
*/

process countAllmRNA {
    errorStrategy 'ignore'
    publishDir "${params.output_dir}", mode: 'copy'
    input:
        file(sampleid_bams) from sampleid_aln_bam.collect()
        file(mRNAgff)
    output:
        file("counts.txt") into counts
    shell:
        """
        featureCounts -T ${params.num_processes} -s 1 -t ${params.featuretype} -g ${params.featurename} -a ${mRNAgff} -o counts.txt ${sampleid_bams.join(" ")} 
        """
}
