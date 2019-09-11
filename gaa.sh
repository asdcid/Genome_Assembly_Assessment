#!/bin/bash


function usage
{
echo '''
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
'''
}


#set default
THREADS=1
READTYPE='pacbio'

#regular expression, test whether some arguments are integer of float
intRe='^[0-9]+$'

#get arguments
while getopts ":hg:o:t:l:x:1:2:A:IBLCES" opt
do
  case $opt in
    g)
      GENOME=$OPTARG
      if [ ! -f "$GENOME" ]
      then
          echo "ERROR: $GENOME is not a file"
          exit 1
      fi
      ;;
    o)
      OUTPUTDIR=$OPTARG
      ;;
    t)
      THREADS=$OPTARG
      if ! [[ $THREADS =~ $intRe ]]
      then
          echo "ERROR: threads should be an integer, $THREADS is not an integer"
          exit 1
      fi
      ;;
    l)
      LONGREAD=$OPTARG
      ;;
    x)
      READTYPE=$OPTARG
      if [ $READTYPE != 'pacbio' -a $READTYPE != 'ont' ]   
      then
          echo "ERROR: readType must be pacbio or ont."
          exit 1
      fi
      ;;
    1)
      R1=$OPTARG
      ;;
    2)
      R2=$OPTARG
      ;;
    I)
      GENERALINFOMARK=true
      ;;
    B)
      BUSCOMARK=true
      ;;
    A)
      LINEAGEBUSCO=$OPTARG
      ;;
    C)
      CGALMARK=true
      ;;
    L)
      LAIMARK=true
      ;;
    E)
      ERRORRATEMARK=true
      ;;
    S)
      STRUCTUREMARK=true
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1

      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      exit 1
      ;;
  esac
done


#check whether set the required arguments
if [ -z "$GENOME" ] || [ -z "$OUTPUTDIR" ]
then
    echo "ERROR: -g or -o has not been set"
    exit 1
fi

#select analysis, if not specify, use all
if [ "$BUSCOMARK" ] || [ "$GENERALINFOMARK" ] || [ "$CGALMARK" ] || [ "$ERRORRATEMARK" ] || [ "$STRUCTUREMARK" ] || [ "$LAIMARK" ]
then
    true
else
    GENERALINFOMARK=true
    BUSCOMARK=true
    CGALMARK=true
    LAIMARK=true
    ERRORRATEMARK=true
    STRUCTUREMARK=true
fi

#check requirement
if [ "$BUSCOMARK" ]
then
    if [ -z "$LINEAGEBUSCO" ] 
    then
        echo "ERROR: BUSCO analysis was selected, the path of lineage for BUSCO must be provide"
        exit 1
    fi
fi


if [ "$CGALMARK" ]
then
    if [ -z "$R1" ] || [ -z "$R2" ]
    then
        echo "ERROR: CGAL analysis was selected, the path of short-read R1 and R2 must be provide"
        exit 1
    fi
fi


if [ "$STRUCTUREMARK" ]
then
    if [ -z "$LONGREAD" ] 
    then
        echo "ERROR: structure variation analysis was selected, the path of long-reads must be provide"
        exit 1
    fi
fi


if [ "$ERRORRATEMARK" ]
then
    if { [ -z "$R1" ] || [ -z "$R2" ] ;} && [ -z "$LONGREAD" ]  
    then
        echo "ERROR: mapping rate and error rate analysis was selected, the path of long-reads or/and short-read R1 and R2 must be provide"
        exit 1
    fi
fi


#output input information
echo "Genome:             $GENOME"
echo "Output folder:      $OUTPUTDIR"
echo "Threads:            $THREADS"

if [ "$LONGREAD" ]
then
    echo "Long-reads:         $LONGREAD"
    echo "Long-read sequencing technology: $READTYPE"
fi

if [ "$R1" ]
then
    echo "Short-read R1:      $R1"
    echo "Short-read R2:      $R2"
fi

if [ "$GENERALINFOMARK" ]
then
    echo "Perform analysis:   General genome statistical information"
fi

if [ "$BUSCOMARK" ]
then
    echo "Perform analysis:   BUSCO"
    echo "Lineage for BUSCO:    $LINEAGEBUSCO"
fi

if [ "$LAIMARK" ]
then
    echo "Perform analysis:   LAI"
fi

if [ "$CGALMARK" ]
then
    echo "Perform analysis:   CGAL" 
fi

if [ "$ERRORRATEMARK" ]
then
    echo "Perform analysis:   mapping rate and error rate"
fi

if [ "$STRUCTUREMARK" ]
then
    echo "Perform analysis:   structure variation"
fi






function run_or_die
{
    code=$1
    step=$2
    if [ "$code" -ne "0" ]
    then
        echo "Error failure: $step "
        exit 1
    else
        echo "Finish $step"
    fi
}


function run_basic_stats
{
    ref=$1 
    outputFile=$2
    script=$3
    $script $ref > $outputFile
    run_or_die $? 'basic_stats'
}


function run_BUSCO
{
    currentPath=$1
    ref=$2
    outputDir=$3
    lineage=$4
    threads=$5
    mode='genome'

    cd $outputDir
    run_or_die $? ''
    busco \
        -i $ref \
        -o 'BUSCO' \
        -l $lineage \
        -m $mode \
        -c $threads
    run_or_die $? 'BUSCO'
    
    cd $currentPath

}


function build_bowtie2_index
{
    ref=$1
    bowtie2-build $ref $ref
    run_or_die $? 'build bowtie2 index ' 
}


function run_qualimap
{
    bamFile=$1
    outputDir=$2
    threads=$3
    qualimap \
        bamqc \
        -bam $bamFile \
        -outdir $outputDir \
        --java-mem-size=10G \
        -nt $threads \
        -c
    run_or_die $? 'base-level error rate detection' 
}


function run_ngmlr
{
    ref=$1
    longRead=$2
    outputDir=$3
    readType=$4
    threads=$5

    ngmlr \
        -t $threads \
        -x $readType \
        --skip-write \
        -r $ref \
        -q $longRead \
        -o $outputDir/ngmlr.sam
    run_or_die $? 'ngmlr long-read alignment (base-level error rate)' 

    samtools view -bS -F 2304 -@ $threads $outputDir/ngmlr.sam > $outputDir/ngmlr.bam
    run_or_die $? 'samtools view long-read alignment (base-level error rate)' 

    samtools sort -@ $threads $outputDir/ngmlr.bam -o $outputDir/ngmlr.sort.bam
    run_or_die $? 'samtools sort long-read alignment (base-level error rate)' 

    samtools index $outputDir/ngmlr.sort.bam
    run_or_die $? 'samtools index long-read alignment (base-level error rate)' 
    
    rm $outputDir/ngmlr.sam
    rm $outputDir/ngmlr.bam
    
    relativeLongReadMap=$outputDir/ngmlr.sort.bam
    longReadMapBam=$(cd $(dirname "$relativeLongReadMap") && pwd -P)/$(basename "$relativeLongReadMap")    

}

function run_bowtie2
{
        
    ref=$1
    R1=$2
    R2=$3
    threads=$4
    outputDir=$5

    bowtie2 \
        -q \
        -x $ref \
        -1 $R1 \
        -2 $R2 \
        -p $threads \
        -S $outputDir/bowtie2.sam
    run_or_die $? 'bowtie2 (base-level error rate)' 


    samtools view -bS -F 264 -@ $threads $outputDir/bowtie2.sam > $outputDir/bowtie2.bam
    run_or_die $? 'samtools view short-read alignment (base-level error rate)' 

    samtools sort -@ $threads $outputDir/bowtie2.bam -o $outputDir/bowtie2.sort.bam
    run_or_die $? 'samtools sort short-read alignment (base-level error rate)' 

    samtools index $outputDir/bowtie2.sort.bam
    run_or_die $? 'samtools index short-read alignment (base-level error rate)' 

    rm $outputDir/bowtie2.sam
    rm $outputDir/bowtie2.bam

    relativeShortReadMap=$outputDir/bowtie2.sort.bam
    shortReadMapBam=$(cd $(dirname "$relativeShortReadMap") && pwd -P)/$(basename "$relativeShortReadMap")    
}


function run_CGAL
{
    ref=$1
    R1=$2
    R2=$3
    threads=$4
    outputDir=$5
    currentPath=$6

    outputSam=$outputDir/cgal.sam

    bowtie2 \
        -q \
        -x $ref \
        -a \
        --no-mixed \
        -1 $R1 \
        -2 $R2 \
        -p $threads \
        -S $outputSam
    run_or_die $? 'bowtie2 (CGAL)' 
    
    cd $outputDir
    
    bowtie2convert cgal.sam
    run_or_die $? 'bowtie2 convert (CGAL)'
 
    rm cgal.sam

    align $ref 500 20
    run_or_die $? 'CGAL align' 

    cgal $ref
    run_or_die $? 'CGAL' 

    cd $currentPath
}


function run_structure_variation
{
    bamFile=$1
    outputFile=$2/structure_variation.vcf
    threads=$3

    sniffles \
            -t $threads \
            -m $bamFile \
            -v $outputFile
    run_or_die $? 'Structure variation' 
}


function run_LAI
{
    ref=$1
    outputDir=$2
    threads=$3

    outputFinder=$outputDir/finder.scn
    outputHarvest=$outputDir/harvest.scn
    outputHarvestNONTGCA=$outputDir/harvest.nonTGCA.scn

    #ltr_finder
    ltr_finder \
        -D 15000 \
        -d 1000 \
        -L 7000 \
        -l 100 \
        -p 20 \
        -C \
        -M 0.9 \
        $ref > $outputFinder
    run_or_die $? 'ltr_finder (LAI)'

    #ltrharvest
    gt suffixerator \
        -db $ref \
        -indexname $ref \
        -tis -suf -lcp -des -ssp -sds -dna
    run_or_die $? 'ltr_harvest prepare (LAI)'

    gt ltrharvest \
        -index $ref \
        -similar 90 \
        -vic 10 \
        -seed 20 \
        -seqids yes \
        -minlenltr 100 \
        -maxlenltr 7000 \
        -mintsd 4 \
        -maxtsd 6 \
        -motif TGCA \
        -motifmis 1 > $outputHarvest
    run_or_die $? 'ltr_harvest TGCA (LAI)'


    gt ltrharvest \
        -index $ref \
        -similar 90 \
        -vic 10 \
        -seed 20 \
        -seqids yes \
        -minlenltr 100 \
        -maxlenltr 7000 \
        -mintsd 4 \
        -maxtsd 6  > $outputHarvestNONTGCA
    run_or_die $? 'ltr_harvest non_TGCA (LAI)'



    #run LTR_retriever to get the LAI score
    LTR_retriever \
        -genome $ref \
        -inharvest $outputHarvest \
        -infinder $outputFinder \
        -nonTGCA $outputHarvestNONTGCA \
        -threads $threads
    run_or_die $? 'ltr_retriever (LAI)'

    #move result from ref dir to outputLAIDir
    mv $ref.pass.list $outputDir
    mv $ref.pass.list.gff3 $outputDir
    mv $ref.LTRlib.fa $outputDir
    mv $ref.nmtf.LTRlib.fa $outputDir
    mv $ref.LTRlib.redundant.fa $outputDir
    mv $ref.out.gff $outputDir
    mv $ref.out.fam.size.list $outputDir
    mv $ref.out.superfam.size.list $outputDir
    mv $ref.out.LTR.distribution.txt $outputDir
    mv $ref.out.LAI $outputDir



}

#start to run this script
SOURCE=$(dirname $0})/scripts/
currentPath="$PWD"
relativeCGALPATH=$SOURCE'/cgal-0.9.6-beta'
CGALPATH=$(cd $(dirname "$relativeCGALPATH") && pwd -P)/$(basename "$relativeCGALPATH")
export PATH=$CGALPATH:$PATH

relativeLTRFinderPath=$SOURCE/LTR_Finder/source
relativeLTRRetriever=$SOURCE/LTR_retriever

LTRFinderPATH=$(cd $(dirname "$relativeLTRFinderPath") && pwd -P)/$(basename "$relativeLTRFinderPath")
LTRRetrieverPATH=$(cd $(dirname "$relativeLTRRetriever") && pwd -P)/$(basename "$relativeLTRRetriever")

export PATH=$LTRFinderPATH:$LTRRetrieverPATH:$PATH

mkdir -p $OUTPUTDIR
run_or_die $? 'create output directory'

refDir=$OUTPUTDIR/'ref'
mkdir -p $refDir
cp $GENOME $refDir/
run_or_die $? 'genome prepare'
relativeRef=$refDir/$(basename $GENOME)
ref=$(cd $(dirname "$relativeRef") && pwd -P)/$(basename "$relativeRef")


if [ "$LINEAGEBUSCO" ]
then
    lineageBUSCO=$(cd $(dirname "$LINEAGEBUSCO") && pwd -P)/$(basename "$LINEAGEBUSCO")
fi


#get the genral infomation, such as N50
if [ "$GENERALINFOMARK" ]
then
    outputGeneralInfoDir=$OUTPUTDIR/'general'
    outputGeneralInfoFile=$outputGeneralInfoDir/'general_information.txt'
    mkdir -p $outputGeneralInfoDir
    run_or_die $? 'create output directory for general information analysis'


    run_basic_stats $ref $outputGeneralInfoFile $SOURCE/basic_stats.py
fi


#BUSCO
if [ "$BUSCOMARK" ]
then
    run_BUSCO $currentPath $ref $OUTPUTDIR $lineageBUSCO $THREADS
fi


#run LAI
if [ "$LAIMARK" ]
then
    outputLAIDir=$OUTPUTDIR/'LAI'
    mkdir -p $outputLAIDir
    run_or_die $? 'create output directory for LAI analysis'

    run_LAI $ref $outputLAIDir $THREADS
fi

#build index for mapping
if [ "$CGALMARK" ] || [ "$ERRORRATEMARK" ]
then
    build_bowtie2_index $ref
fi

#do the long-read mapping
if [ "$LONGREAD" ]
then
    mapDir=$OUTPUTDIR/'mapping'
    outputNgmlrDir=$mapDir/'Ngmlr'

    mkdir -p $outputNgmlrDir
    if [ "$ERRORRATEMARK" ] || [ "$STRUCTUREMARK" ]
    then
        run_ngmlr $ref $LONGREAD $outputNgmlrDir $READTYPE $THREADS
    fi
fi

#base-level error rate
if [ "$ERRORRATEMARK" ]
then
    outputErrorRateDir=$OUTPUTDIR/'Error_rate'
    mkdir -p $outputErrorRateDir
    run_or_die $? 'create output directory for mapping rate and error rate analysis'

    if [ "$R1" ] && [ "$R2" ]
    then
        mapDir=$OUTPUTDIR/'mapping'
        outputBowtie2Dir=$mapDir/'Bowtie2'
        mkdir -p $outputBowtie2Dir

        outputShortReadErrorRateDir=$outputErrorRateDir/'short-read'
        mkdir -p $outputShortReadErrorRateDir

        run_bowtie2 $ref $R1 $R2 $THREADS $outputBowtie2Dir

        run_qualimap $shortReadMapBam $outputShortReadErrorRateDir $THREADS
    fi

    if [ "$LONGREAD" ]
    then
        outputLongReadErrorRateDir=$outputErrorRateDir/'long-read'
        mkdir -p $outputLongReadErrorRateDir
        
        run_qualimap $longReadMapBam $outputLongReadErrorRateDir $THREADS
    fi
fi

#run CGAL
if [ "$CGALMARK" ]
then
    outputCGALDir=$OUTPUTDIR/'CGAL'
    mkdir -p $outputCGALDir
    run_or_die $? 'create output directory for CGAL analysis'
    
    run_CGAL $ref $R1 $R2 $THREADS $outputCGALDir $currentPath 
fi

#run structure variation
if [ "$STRUCTUREMARK" ]
then
    outputSVDir=$OUTPUTDIR/'StructureVariation'
    mkdir -p $outputSVDir
    run_or_die $? 'create output directory for structure variation analysis'

    run_structure_variation $longReadMapBam $outputSVDir $THREADS 
fi




