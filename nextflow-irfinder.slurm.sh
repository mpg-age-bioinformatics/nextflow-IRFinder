#!/bin/bash

source IRfinder.config

## usage:
## $1 : `release` for latest nextflow/git release; `checkout` for git clone followed by git checkout of a tag ; `clone` for latest repo commit
## $2 : profile

set -e

get_latest_release() {
  curl --silent "https://api.github.com/repos/$1/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/'
}

wait_for(){
    PID=$(echo "$1" | cut -d ":" -f 1 )
    PRO=$(echo "$1" | cut -d ":" -f 2 )
    echo "$(date '+%Y-%m-%d %H:%M:%S'): waiting for ${PRO}"
    wait $PID
    CODE=$?
    
    if [[ "$CODE" != "0" ]] ; 
        then
            echo "$PRO failed"
            echo "$CODE"
            failed=true
            #exit $CODE
    fi
}

failed=false

PROFILE=$2
LOGS="work"
PARAMS="params.json"

mkdir -p ${LOGS}

if [[ "$1" == "release" ]] ; 
  then

    ORIGIN="mpg-age-bioinformatics/"
    
    FASTQC_RELEASE=$(get_latest_release ${ORIGIN}nf-fastqc)
    echo "${ORIGIN}nf-fastqc:${FASTQC_RELEASE}" >> ${LOGS}/software.txt
    FASTQC_RELEASE="-r ${FASTQC_RELEASE}"

    KALLISTO_RELEASE=$(get_latest_release ${ORIGIN}nf-kallisto)
    echo "${ORIGIN}nf-kallisto:${KALLISTO_RELEASE}" >> ${LOGS}/software.txt
    KALLISTO_RELEASE="-r ${KALLISTO_RELEASE}"

    IRFINDER_RELEASE=$(get_latest_release ${ORIGIN}nf-IRFinder)
    echo "${ORIGIN}nf-IRFinder:${IRFINDER_RELEASE}" >> ${LOGS}/software.txt
    IRFINDER_RELEASE="-r ${IRFINDER_RELEASE}"

    MULTIQC_RELEASE=$(get_latest_release ${ORIGIN}nf-multiqc)
    echo "${ORIGIN}nf-multiqc:${MULTIQC_RELEASE}" >> ${LOGS}/software.txt
    MULTIQC_RELEASE="-r ${MULTIQC_RELEASE}"

    uniq ${LOGS}/software.txt ${LOGS}/software.txt_
    mv ${LOGS}/software.txt_ ${LOGS}/software.txt
    
else

  for repo in nf-fastqc nf-kallisto nf-IRFinder nf-multiqc ; 
    do

      if [[ ! -e ${repo} ]] ;
        then
          git clone git@github.com:mpg-age-bioinformatics/${repo}.git
      fi

      if [[ "$1" == "checkout" ]] ;
        then
          cd ${repo}
          git pull
          RELEASE=$(get_latest_release ${ORIGIN}${repo})
          git checkout ${RELEASE}
          cd ../
          echo "${ORIGIN}${repo}:${RELEASE}" >> ${LOGS}/software.txt
      else
        cd ${repo}
        COMMIT=$(git rev-parse --short HEAD)
        cd ../
        echo "${ORIGIN}${repo}:${COMMIT}" >> ${LOGS}/software.txt
      fi

  done

  uniq ${LOGS}/software.txt >> ${LOGS}/software.txt_ 
  mv ${LOGS}/software.txt_ ${LOGS}/software.txt

fi

get_images() {
  echo "- downloading images"
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1 && \
  nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -entry images -profile ${PROFILE} >> ${LOGS}/get_images.log 2>&1
}

run_upload(){
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -entry upload -profile ${PROFILE} >> ${LOGS}/nf-fastqc.log 2>&1
  nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -entry upload -profile ${PROFILE} >> ${LOGS}/nf-multiqc.log 2>&1
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry upload -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1
}

run_qc() {
  echo "- running fastqc and multiqc"
  nextflow run ${ORIGIN}nf-fastqc ${FASTQC_RELEASE} -params-file ${PARAMS} -profile ${PROFILE} >> ${LOGS}/nf-fastqc.log 2>&1 && \
  nextflow run ${ORIGIN}nf-multiqc ${MULTIQC_RELEASE} -params-file ${PARAMS} -profile ${PROFILE} >> ${LOGS}/multiqc.log 2>&1
}

run_kallisto_get_genome() {
  echo "- getting genome files"
  nextflow run ${ORIGIN}nf-kallisto ${KALLISTO_RELEASE} -params-file ${PARAMS} -entry get_genome -profile ${PROFILE} >> ${LOGS}/kallisto.log 2>&1
}

run_IRFinder() {
  echo "- starting IRFinder analysis"
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry repo_IRFinder -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1  && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_small_intron_calc -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_build_ref -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_quantify_ir -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_make_comps -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_noRep_diff -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1 && \
  nextflow run ${ORIGIN}nf-IRFinder ${IRFINDER_RELEASE} -params-file ${PARAMS} -entry run_wRep_diff -profile ${PROFILE} >> ${LOGS}/nf-irfinder.log 2>&1
}

get_images & IMAGES_PID=$! 
wait_for "${IMAGES_PID}:IMAGES"

run_qc & QC_PID=$!
sleep 1

run_kallisto_get_genome & KALLISTO_PID=$!
sleep 1

for PID in "${QC_PID}:QC" "${KALLISTO_PID}:KALLISTO"
  do
    wait_for $PID
done

run_IRFinder & IRFINDER_PID=$!
wait_for "${IRFINDER_PID}:IRFINDER"

run_upload & UPLOAD_PID=$!
wait_for "${UPLOAD_PID}:UPLOAD"


rm -rf ${project_folder}/upload.txt
cat $(find ${project_folder}/ -name upload.txt) > ${project_folder}/upload.txt
sort -u ${LOGS}/software.txt > ${LOGS}/software.txt_
mv ${LOGS}/software.txt_ ${LOGS}/software.txt
cp ${LOGS}/software.txt ${project_folder}/software.txt
cp README_IRfinder.md ${project_folder}/README_IRfinder.md
echo "main $(readlink -f ${project_folder}/software.txt)" >> ${project_folder}/upload.txt
echo "main $(readlink -f ${project_folder}/README_IRfinder.md)" >> ${project_folder}/upload.txt
cp ${project_folder}/upload.txt ${upload_list}
echo "- done" && sleep 1

exit
