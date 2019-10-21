# Genome_Assembly_Assessment

This pipeline was used for different assembly assessments in this paper (doi: https://doi.org/10.1101/678730).

**gaa.sh**: Scripts for genome assembly assessment. Detect general genome statistical information, BUSCO, LAI, CGAL, mapping rate and base-level error rate, and structure variation. The result can be used for comparing different genome assemblies. 

**whole_genome_alignment.sh**: Script for whole genome alignment between two genome assemblies.

## Install

```
git clone https://github.com/asdcid/Genome_Assembly_Assessment.git
cd Genome_Assembly_Assessment

#conda is required to install first. How to install conda: https://docs.anaconda.com/anaconda/install/
conda env create -f environment.yml
source activate GAA

#install CGAL
cd scripts
tar -xvf cgal-0.9.6-beta.tar
cd cgal-0.9.6-beta/
make
cd ..

#install LAI
cd LTR_Finder
cd source
make 
cd ../..

#install LTR_retriever
git clone https://github.com/oushujun/LTR_retriever.git
```

The repeatMasker is required for LAI analysis. It is needed to install manually (http://www.repeatmasker.org/RMDownload.html)

## Usage
**gaa.sh**
```
[Script for genome assembly assessment. Detect general genome statistical information, BUSCO, LAI, CGAL, mapping rate and base-level error rate, and structure variation]
NOTE:
The following assessment methods required long or short-reads.
    CGAL                                        Short-reads (illumina)
    Structural variation                        Long-reads  (pacbio or ont)
    mapping rate and base-level error rate      Long or short-reads


Usage: bash gaa.sh -g genome.fa -o outputDir [options]
General:
    -g <file>
            Path of genome, in fasta format. Required.
    -o <directory>
            Path of outputDir. Required.
    -t <int>
            Number of threads. Default is 1.

Long-reads (pacbio or ont reads):
    -l <file>
            Path of long-read file in fasta/fastq format, can be compressed(.gz).
    -x <pacbio, ont>
        sequencing technology of long-read, only can be pacbio (PacBio reads) or ont (Nanopore reads). Default is pacbio.

Short-reads (illumina reads):
    -1 <file>
            Path of short-read file with #1 mates, paired with files in -2. The file should be in fasta/fastq format, can be compressed(.gz).
    -2 <file>
            Path of short-read file with #2 mates, paired with files in -2. The file should be in fasta/fastq format, can be compressed(.gz).

Assessment methods (If unspecify, all assessment methods will be used):
    -I
            General genome statistical information analysis
    -B
            BUSCO, Benchmarking Universal Single-Copy Orthologs
    -A <directory>
            Specify location of the BUSCO lineage data to be used. Required if choose BUSCO anlysis
            Visit http://busco.ezlab.org for available lineages.
    -L
            LAI analysis, LTR Assembly Index
    -C
            CGAL analysis, Computing Genome Assembly Likelihoods. Required short-reads
    -E
            Mapping rate and base-level error rate analysis. Required long/short-reads.
            If only one type of read is provided, this assessment will only perform on that type of reads.
            Otherwise, it will detect the mapping rate and base-level error rate in long and short-read levels.
    -S
            Structural variation analysis. Required long-reads)
```


**whole_genome_alignment.sh**
```
[Script for whole genome alignment comparsion for two assemblies.

Usage: bash whole_genome_alignment.sh -r reference_assembly.fa -q query_assembly.fa -o output_prefix [options]
Required:
    -r <file>
            Path of reference assembly, in fasta format.
    -q <file>
            Path of query genome, in fasta format.
    -o
            Path of output prefix
Options:
    -t <int>
            Number of threads. Default is 1.
    -i <int>
            The minimum alignment identity [0, 100]. Default is 75.
```


## Test
```
cd test_data
# bacteria_odb9.tar.gz is the database for BUSCO analysis (E.coli)
tar -zxvf bacteria_odb9.tar.gz
cd ..


bash gaa.sh \
    -g test_data/genome/E.coli_K12_MG1655.fa \
    -o test \
    -1 test_data/reads/short_read_1.fastq.gz \
    -2 test_data/reads/short_read_2.fastq.gz \
    -l test_data/reads/long_read.fastq.gz \
    -A test_data/bacteria_odb9 
```
NOTE: it is just a test, the structure variation and LAI will return no result because of the small dataset.

```
outputDir='test_wholeGenomeAlignment'
mkdir -p $outputDir
bash whole_genome_alignment.sh \
    -r test_data/genome/E.coli_K12_MG1655.fa \
    -q test_data/genome/E.coli_K12_MG1655.fa \
    -o $outputDir/test
```
