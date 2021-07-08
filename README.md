# CryptoGat201RNASeq_draft
Cryptococcus neoformans RNA-seq Gat201 strains 2021.

Data created by Liz Hughes, December 2020. 
Analysis started by Edward Wallace, February 2021

# Contents

* src - scripts for data processing
* input_annotation - Cryptococcus genome annotation used for read alignment and counting.
* input_experiment - other input files including sample sheet
* results - output data and results
* results_counts - Results consisting of count data and analyses of those.

## How we made the subsampled data

It is strongly recommended to do a test run on small yet real data - subsampled data - before running on a large dataset.
An example of subsampling fastq files is:

```
gzip -dkc EH_050221_Data/1_S1_R1_001.fastq.gz \
  | head -n 400000 | gzip > EH_050221_Data_subsample/1_S1_R1_001_init100000.fastq.gz

gzip -dkc EH_050221_Data/2_S44_R1_001.fastq.gz \
  | head -n 400000 | gzip > EH_050221_Data_subsample/2_S44_R1_001_init100000.fastq.gz
```


## How to run the pipeline

First edit the parameters in `src/quantseqfwd.nf` so that

* `params.input_fq_dir` points to an input directory containing all of your fastq files 
* `params.output_dir` points to the output directory where you would like all the outputs stored.

Then run the command:

```
nextflow run src/quantseqfwd.nf -with-dag flowchart.png -with-report nextflow_report.html
```

The options `-with-dag` and `-with-report` are just to tell you a little more about the output, they are not strictly needed in order to run.

# Output files

results_counts: contains the analysis from the count data including a clustered heatmap, dendogram, TPM plots, normalized clustered heatmap, gene summary table, PCA plots and plot mean TPMs.

results_deseq: contains rlog transformation, sample distances, heatmap using rlog transformed data - for all samples, o hrs, 30 mins, 2 hrs and 4 hrs - ,PCA analysis - ohrs, 30 min, 2 hrs and 4 hrs -, DEG analysis, plotting individula genes, MA plots using rlog, Look at top expressed genes at all time points and create heatmaps for each, create Gene description file from GFF3 file.

results_deseq_2: DEG analysis adapting code from Dian's analysis to my data set and putting it into .Rmd format, MA plots, Volcano plots for differentially expresed genes and volcano plots for GAT201 regulated genes, produce gene lists for differentially expressed genes at each time point of the analysis.

.Rmd files: Contains files produced from R analysis and html files.

