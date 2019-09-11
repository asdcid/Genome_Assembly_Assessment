#!/bin/bash

set -e

function usage
{
echo '''
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
'''
}

#set default
IDENTITY=75
THREADS=1

while getopts ":hr:q:o:t:i" opt
do
  case $opt in
    r)
      REFERENCE=$OPTARG
      if [ ! -f "$REFERENCE" ]
      then
          echo "ERROR: $REFERENCE is not a file"
          exit 1
      fi
      ;;
    q)
      QUERY=$OPTARG
      if [ ! -f "$QUERY" ]
      then
          echo "ERROR: $QUERY is not a file"
          exit 1
      fi
      ;;
    o)
      OUTPUTPREFIX=$OPTARG
      ;;
    t)
      THREADS=$OPTARG
      if ! [[ $THREADS =~ $intRe ]]
      then
          echo "ERROR: threads should be an integer, $THREADS is not an integer"
          exit 1
      fi
      ;;
    i)
      IDENTITY=$OPTARG
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
if [ -z "$REFERENCE" ] || [ -z "$OUTPUTPREFIX" ] || [ -z "QUERY" ]
then
    echo "ERROR: -r or -q or -o has not been set"
    usage
    exit 1
fi

nucmer \
        --maxmatch  \
        --prefix=$OUTPUTPREFIX  \
        $REFERENCE \
        $QUERY

delta-filter \
    -m \
    -i $IDENTITY \
    $OUTPUTPREFIX.delta > ${OUTPUTPREFIX}.${IDENTITY}.delta


dnadiff -d ${OUTPUTPREFIX}.${IDENTITY}.delta \
    --prefix=$OUTPUTPREFIX


