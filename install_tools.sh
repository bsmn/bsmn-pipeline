#!/bin/bash

set -o errexit -o nounset -o pipefail -o xtrace

WD=$(pwd)

# Installing Python3 is ommited because linux distributions like Amazon linux come with Python3.
# Amazon linux has pyenv installed but to make Python3 accessible from the PATH the PYENV_VERSION
# environmental variable must be set to the Python3 version installed by pyenv and then exported.
# To do so add the following line (after checking the installed Python3 version with `pyenv
# versions`) to ~/.bashrc:
#
# export PYENV_VERSION=3.6.9
#
# Note that pip/pip3 need not be installed either because it also comes with linuxes.
#

#DIR=$WD/tools/python/3.6.2
#
#URL="https://www.python.org/ftp/python/3.6.2/Python-3.6.2.tgz"
#if [[ ! -f $DIR/installed ]]; then
#    mkdir -p $DIR/src
#    cd $DIR/src
#    wget -qO- $URL |tar xvz --strip-components=1
#    ./configure --with-ensurepip=install --prefix=$DIR 
#    make
#    make install
#    cd $WD
#    rm -r $DIR/src
#    touch $DIR/installed
#fi

# Installing Python modules needed
#$DIR/bin/pip3 install -Uq pip

# for bsmn_pipeline itself
python3 -m pip install -U --user awscli synapseclient statsmodels scipy awscli synapseclient statsmodels scipy 
# rpy2 fails to install with "gcc: error: libgomp.spec: No such file or directory"
#python3 -m pip install -U --user rpy2 

# for MosaicForecast
python3 -m pip install -U --user pysam numpy pandas pysamstats regex scipy pyfaidx 

# for RetroSom
python3 -m pip install -U --user cutadapt 

# Installling Java8
DIR=$WD/tools/java/jdk1.8.0_222
URL="https://github.com/ojdkbuild/contrib_jdk8u-ci/releases/download/jdk8u222-b10/jdk-8u222-ojdkbuild-linux-x64.zip"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget $URL
    unzip jdk*.zip
    rm jdk*.zip
    mv jdk*/* $DIR
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

exit
# Installing bwa
DIR=$WD/tools/bwa/0.7.16a
URL="https://github.com/lh3/bwa/releases/download/v0.7.16/bwa-0.7.16a.tar.bz2"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/bin $DIR/share/man/man1 $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvj --strip-components=1
    make 
    mv bwa $DIR/bin 
    mv *.pl $DIR/bin
    mv bwa.1 $DIR/share/man/man1
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing samtools
DIR=$WD/tools/samtools/1.7
URL="https://github.com/samtools/samtools/releases/download/1.7/samtools-1.7.tar.bz2"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvj --strip-components=1
    ./configure --prefix=$DIR
    make
    make install
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing htslib
DIR=$WD/tools/htslib/1.7
URL="https://github.com/samtools/htslib/releases/download/1.7/htslib-1.7.tar.bz2"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvj --strip-components=1
    ./configure --prefix=$DIR
    make
    make install
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing bcftools
DIR=$WD/tools/bcftools/1.7
URL="https://github.com/samtools/bcftools/releases/download/1.7/bcftools-1.7.tar.bz2"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvj --strip-components=1
    ./configure --prefix=$DIR
    make
    make install
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing sambamba
DIR=$WD/tools/sambamba/0.6.7
URL="https://github.com/biod/sambamba/releases/download/v0.6.7/sambamba_v0.6.7_linux.tar.bz2"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/bin
    cd $DIR/bin
    wget -qO- $URL |tar xvj
    cd $WD
    touch $DIR/installed
fi
unset DIR URL

# Installing vt
DIR=$WD/tools/vt/2018-06-07
URL="http://github.com/atks/vt/archive/ee9f613.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/bin $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    make
    mv vt $DIR/bin
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing root
# prerequisite cmake > 3.4.3
DIR=$WD/tools/cmake/3.11.4
URL="https://cmake.org/files/v3.11/cmake-3.11.4-Linux-x86_64.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR
    wget -qO- $URL |tar xvz --strip-components=1 -C $DIR
    touch $DIR/installed
fi

# build root
ROOTSYS=$WD/tools/root/6.14.00
ROOTURL="https://root.cern.ch/download/root_v6.14.00.source.tar.gz"
if [[ ! -f $ROOTSYS/installed ]]; then
    mkdir -p $ROOTSYS/src/root
    cd $ROOTSYS/src
    wget -qO- $ROOTURL |tar xvz --strip-components=1 -C root
    $DIR/bin/cmake -Dbuiltin_pcre=ON -Dbuiltin_vdt=ON -Dhttp=ON -Dgnuinstall=ON \
        -DCMAKE_INSTALL_PREFIX=$ROOTSYS root
    $DIR/bin/cmake --build . -- -j$(nproc)
    $DIR/bin/cmake --build . --target install
    cd $WD
    rm -r $ROOTSYS/src
    touch $ROOTSYS/installed
fi
unset DIR URL ROOTURL

# Installing cnvnator
DIR=$WD/tools/cnvnator/0.4
URL="https://github.com/abyzovlab/CNVnator/archive/v0.4.tar.gz"
SAMURL="https://github.com/samtools/samtools/releases/download/1.7/samtools-1.7.tar.bz2"
set +o nounset
source $ROOTSYS/bin/thisroot.sh
set -o nounset
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/bin $DIR/src/samtools
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    cd samtools
    wget -qO- $SAMURL |tar xvj --strip-components=1
    make
    cd ..
    sed -i '2s/$/ -lpthread/' Makefile
    make OMP=no
    mv cnvnator ../bin
    mv cnvnator2VCF.pl ../bin
    mv *.py ../bin
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL SAMURL ROOTSYS

# Installing Picard
DIR=$WD/tools/picard/2.17.4
URL="https://github.com/broadinstitute/picard/releases/download/2.17.4/picard.jar"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR
    cd $DIR
    wget -q $URL
    cd $WD
    touch $DIR/installed
fi
unset DIR URL

if false; then
# Installing GATK3
DIR=$WD/tools/gatk/3.7-0
URL="https://storage.cloud.google.com/gatk-software/package-archive/gatk/GenomeAnalysisTK-3.7-0-gcfedb67.tar.bz2"
#URL="https://software.broadinstitute.org/gatk/download/auth?package=GATK-archive&version=3.7-0-gcfedb67"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR
    cd $DIR
    wget -qO- $URL |tar xvj
    cd $WD
    touch $DIR/installed
fi
unset DIR URL
fi

# Installing GATK4
DIR=$WD/tools/gatk/4.1-2
URL="https://github.com/broadinstitute/gatk/releases/download/4.1.2.0/gatk-4.1.2.0.zip"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget $URL
    unzip gatk-4.*.zip
    rm gatk-4.*.zip
    mv gatk-4.*/* $DIR
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

# Installing R
DIR=$WD/tools/r/3.6.1
URL="https://cran.r-project.org/src/base/R-3/R-3.6.1.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    ./configure --prefix=$DIR
    make
    make install
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi

# Insatlling R packages needed
$DIR/bin/R --no-save <<'RCODE'
# for MosaicForecast
install.packages(setdiff(
    c("XML", "ggplot2", "caret", "e1071", "glmnet", "RColorBrewer", "devtools", "nnet"),
    installed.packages()[,"Package"]), repos="https://cloud.r-project.org")

# for RestroSom
install.packages(setdiff(
    c("randomForest", "glmnet", "e1071", "PRROC"), 
    installed.packages()[,"Package"]), repos="https://cloud.r-project.org")
RCODE
unset DIR URL

# Installing MosaicForecast and depending tools
cd tools
[[ ! -d MosaicForecast ]] && git clone https://github.com/parklab/MosaicForecast.git MosaicForecast
cd $WD

mkdir -p tools/ucsc
cd tools/ucsc
for CMD in wigToBigWig bigWigAverageOverBed fetchChromSizes; do
    if [[ ! -x $CMD ]]; then
        wget http://hgdownload.cse.ucsc.edu/admin/exe/linux.x86_64/$CMD
        chmod +x $CMD
    fi
done
cd $WD

if false; then

# Installing Perl and modules needed
DIR=$WD/tools/perl/5.28.1
URL="https://www.cpan.org/src/5.0/perl-5.28.1.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    ./Configure -des -Dprefix=$DIR
    make
    make test
    make install
    cd $WD
    rm -rf $DIR/src
    touch $DIR/installed
fi

# Installing Perl modules needed
for MD in GD GD::Arrow GD::SVG Parallel::ForkManager; do
    wget -qO- https://cpanmin.us |$DIR/bin/perl - $MD
done
unset DIR URL

fi

# Installing RetroSom and depending tools
DIR=$WD/tools/bedtools/2.28.0
URL="https://github.com/arq5x/bedtools2/releases/download/v2.28.0/bedtools-2.28.0.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    make
    mv bin ..
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

DIR=$WD/tools/exonerate/2.2.0
URL="http://ftp.ebi.ac.uk/pub/software/vertebrategenomics/exonerate/exonerate-2.2.0.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget -qO- $URL |tar xvz --strip-components=1
    ./configure --prefix=$DIR
    make
    make install
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

DIR=$WD/tools/bwakit/0.7.15
URL="https://sourceforge.net/projects/bio-bwa/files/bwakit/bwakit-0.7.15_x64-linux.tar.bz2/download"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR
    cd $DIR
    wget -qO- $URL |tar xvj --strip-components=1
    cd $WD
    touch $DIR/installed
fi
unset DIR URL

DIR=$WD/tools/fastqc/0.11.8
URL="http://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.8.zip"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR/src
    cd $DIR/src
    wget $URL
    unzip fastqc*.zip
    mv FastQC/* $DIR
    cd $WD
    rm -r $DIR/src
    touch $DIR/installed
fi
unset DIR URL

DIR=$WD/tools/blast/2.9.0
URL="ftp://ftp.ncbi.nlm.nih.gov/blast/executables/blast+/2.9.0/ncbi-blast-2.9.0+-x64-linux.tar.gz"
if [[ ! -f $DIR/installed ]]; then
    mkdir -p $DIR
    cd $DIR
    wget -qO- $URL |tar xvz --strip-components=1
    cd $WD
    touch $DIR/installed
fi
unset DIR URL
