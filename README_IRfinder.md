# bit_pipe_IRfinder

---

This Document describes the IRfinder pipeline and output.  
The pipeline is based on [this](https://github.com/williamritchie/IRFinder/wiki) tutorial


### Pipeline:
1. Build references from local fasta and gtf files (Ensembl build 103)
2. Quantify intron retention from FASTQ files directly
3. Differential IR testing  
  3a if less than three replicates, single samples are compared using `analysisWithNoReplicates.pl` in a pairwise comparison manner [Audic and Clabarie test](https://pubmed.ncbi.nlm.nih.gov/9331369/)  
  3b if three or more replicates are available for each group all pairwise comparisons are evaluated by using `DESeq2`.  

### DESeq2 model
The model includes two contrasts. 
  1. the different condtion/treatment group
  2. normal splice site or intron retention
  
First it is tested if the number of IR reads are significantly different from normal spliced reads in both groups individually.  
Then the difference of (intronic reads/normal spliced reads) ratio between both groups is tested.
  
### Output
The output is grouped in three folders.  
1. The fastqc reports (and a multiQC summary)  
2. The IRquant files (for output description see [here](https://github.com/williamritchie/IRFinder/wiki/IRFinder-Output))  
3. The IRdiff results:  

**comparison.xlsx**  

| Column Name | Contents |
|-----|----------|
| gene name (no title)  | The intron/gene identifier |
| diff.baseMean         | The overall normalized mean when considering all samples |
| diff.log2FoldChange   | DESeq2 calculated log2 fold changes of IR/splice ratio between the groups |
| diff.lfcSE            | DESeq2 calculated standard error of the fold change |
| diff.stat             | DESeq2 calculated test statistic for testing group1 vs group2 (Wald test: the log2FoldChange divided by lfcSE) |
| diff.pvalue           | DESeq2 calculated p-value for testing group1 vs group2 |
| diff.padj             | DESeq2 calculated p-value adjusted for multiple hypothesis testing |
| diff.IR.change        | IRfinder suggested calculation: group2.IRratio - group1.IRratio |
| group1(group2).baseMean       | The overall normalized mean calculated in one group |
| group1(group2).log2FoldChange | DESeq2 calculated log2 fold changes of IR/splice ratio within one group |
| group1(group2).lfcSE          | DESeq2 calculated standard error of the fold change |
| group1(group2).stat           | DESeq2 calculated test statistic for testing IR/splice ratio within one group |
| group1(group2).pvalue         | DESeq2 calculated p-value for testing IR/splice ratio within one group |
| group1(group2).padj           | DESeq2 calculated p-value adjusted for multiple hypothesis testing |
| group1(group2).IR_vs_Splice   | IRfinder suggested calculation: 2^log2FoldChange |
| group1(group2).IRratio        | IRfinder suggested calculation: IR_vs_Splice/(1+IR_vs_Splice) = IR ratio is calculated as (intronic reads/(intronic reads+normal spliced reads))|


**comparison.pdf**  

First plot shows the IRfinder suggested output that shows the IR.change on the y-axis and an unsorted index on the x-axis. The red dots signify introns with an adjusted p-value <= 0.05 and an IR.change > 10%  
The second plot shows a volcano plot with the Log2FC on the x-axis and the negative log10 adjusted p.value. The red dots signify introns with an adjusted p-value <= 0.05 and an IR.change > 10%  



**File1.vs.File2.txt**  (in case of missing replicates)

| Column Name | Contents |
|---- |-----------|
| Chr	                   | Chromosome of tested intron |
| Start                  | Start coordinate of intron |	
| End                    | End coordinate of intron	|
| Intron-GeneName/GeneID | Intron identifier |	
| -                      | irrelevant score column left over from bed format  |
| Direction	             | strand intron is located on |
| ExcludedBases          | This is the number of bases within the intronic region that have been excluded from the calculation of intronic coverage because of overlapping features or mapping issues. |	
| p-diff	               | tells you how different the two IR values are between the two samples, no matter increase or decrease. You can consider this is the summary/minimum of the other two p values |
| p-increased	           | tells you the significance of IR increase in the other sample compared to the baseline sample. |
| p-decreased	           | tells you the significance of IR decrease in the other sample compared to the baseline sample. |
| A(B)-IRratio	         | IRratio = IntronDepth / (max(splices right , splices left) + IntronDepth) per individual sample |
| A(B)-IRok	             | The warining tag is generated from the values in the previous columns, and the cutoff is hard-coded. Description on the bottome  [here](https://github.com/williamritchie/IRFinder/wiki/IRFinder-Output)|
| A(B)-IntronCover	     | Ratio of bases with mapped reads. |
| A(B)-IntronDepth	     | Depth is the number of reads that map over a given bp. IntronDepth is the median depth of the intronic region without the excluded regions. It is used to calculate the IRratio. Excluded regions comprise ExclBases and bases with the top and bottom 30% of intronic depth. |
| A(B)-SplicesMax	       | max of the number of reads that map the 5' or 3' flanking exon surrounding the intron and to another exon within the same gene. |
| A(B)-SplicesExact	     | This is the number of reads that map across the 3' and 5' flanking exons. |

*The baseline sample is the sample fed by -B, which corresponds to the second file listed*  

*Note*: all other files are input files for the differential analysis


### References
1. [IRfinder](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-017-1184-4)
2. [Audic and Clabarie test](https://pubmed.ncbi.nlm.nih.gov/9331369/)
3. [DESeq2](https://genomebiology.biomedcentral.com/articles/10.1186/s13059-014-0550-8)
