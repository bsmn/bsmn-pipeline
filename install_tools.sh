#!/bin/bash

WD=$(pwd)

# Installing Python3
mkdir -p tools/python/3.6.2/src
cd tools/python/3.6.2/src
wget -qO- https://www.python.org/ftp/python/3.6.2/Python-3.6.2.tgz \
    |tar xvz --strip-components=1
./configure --with-ensurepip=install --prefix=$WD/tools/python/3.6.2
make 
make install
cd $WD
rm -r tools/python/3.6.2/src

# Installing Python modules needed
tools/python/3.6.2/bin/pip3 install --upgrade pip
tools/python/3.6.2/bin/pip3 install awscli synapseclient statsmodels scipy rpy2

# Installling Java8
mkdir -p tools/java
cd tools/java
wget -qO- --no-check-certificate --header "Cookie: oraclelicense=a" \
    http://download.oracle.com/otn-pub/java/jdk/8u191-b12/2787e4a523244c269598db4e85c51e0c/jdk-8u191-linux-x64.tar.gz \
    |tar xvz
cd $WD

# Installing bwa
mkdir -p tools/bwa/0.7.16a/bin
mkdir -p tools/bwa/0.7.16a/share/man/man1
mkdir -p tools/bwa/0.7.16a/src
cd tools/bwa/0.7.16a/src
wget -qO- https://github.com/lh3/bwa/releases/download/v0.7.16/bwa-0.7.16a.tar.bz2 \
    |tar xvj --strip-components=1
make
mv bwa ../bin
mv *.pl ../bin
mv bwa.1 ../share/man/man1
cd $WD
rm -r tools/bwa/0.7.16a/src

# Installing samtools
mkdir -p tools/samtools/1.7/src
cd tools/samtools/1.7/src
wget -qO- https://github.com/samtools/samtools/releases/download/1.7/samtools-1.7.tar.bz2 \
    |tar xvj --strip-components=1
./configure --prefix=$WD/tools/samtools/1.7
make
make install
cd $WD
rm -r tools/samtools/1.7/src

# Installing htslib
mkdir -p tools/htslib/1.7/src
cd tools/htslib/1.7/src
wget -qO- https://github.com/samtools/htslib/releases/download/1.7/htslib-1.7.tar.bz2 \
    |tar xvj --strip-components=1
./configure --prefix=$WD/tools/htslib/1.7
make
make install
cd $WD
rm -r tools/htslib/1.7/src

# Installing bcftools
mkdir -p tools/bcftools/1.7/src
cd tools/bcftools/1.7/src
wget -qO- https://github.com/samtools/bcftools/releases/download/1.7/bcftools-1.7.tar.bz2 \
    |tar xvj --strip-components=1
./configure --prefix=$WD/tools/bcftools/1.7
make
make install
cd $WD
rm -r tools/bcftools/1.7/src

# Installing sambamba
mkdir -p tools/sambamba/v0.6.7/bin
cd tools/sambamba/v0.6.7/bin
wget -qO- https://github.com/biod/sambamba/releases/download/v0.6.7/sambamba_v0.6.7_linux.tar.bz2 \
    |tar xvj
cd $WD

# Installing vt
mkdir -p tools/vt/2018-06-07/bin
mkdir -p tools/vt/2018-06-07/src
cd tools/vt/2018-06-07/src
wget -qO- http://github.com/atks/vt/archive/ee9f613.tar.gz \
    |tar xvz --strip-components=1
make
mv vt ../bin
cd $WD
rm -r tools/vt/2018-06-07/src

# Installing root
# prerequisite cmake > 3.4.3
mkdir -p tools/cmake/3.11.4
wget -qO- https://cmake.org/files/v3.11/cmake-3.11.4-Linux-x86_64.tar.gz \
    |tar xvz --strip-components=1 -C tools/cmake/3.11.4

# build root
mkdir -p tools/root/6.14.00/src
cd tools/root/6.14.00/src
wget -qO- https://root.cern.ch/download/root_v6.14.00.source.tar.gz \
    |tar xvz
$WD/tools/cmake/3.11.4/bin/cmake \
    -Dbuiltin_pcre=ON -Dhttp=ON -Dgnuinstall=ON \
    -DCMAKE_INSTALL_PREFIX=$WD/tools/root/6.14.00 \
    root-6.14.00
$WD/tools/cmake/3.11.4/bin/cmake --build . -- -j 
$WD/tools/cmake/3.11.4/bin/cmake --build . --target install
cd $WD
rm -r tools/root/6.14.00/src

# Installing cnvnator
source $WD/tools/root/6.14.00/bin/thisroot.sh
mkdir -p tools/cnvnator/2018-07-09/bin
mkdir -p tools/cnvnator/2018-07-09/src/samtools
cd tools/cnvnator/2018-07-09/src
wget -qO- https://github.com/abyzovlab/CNVnator/archive/de012f2.tar.gz \
    |tar xvz --strip-components=1
cd samtools
wget -qO- https://github.com/samtools/samtools/releases/download/1.7/samtools-1.7.tar.bz2 \
    |tar xvj --strip-components=1
make
cd ..
sed -i '2s/$/ -lpthread/' Makefile
make OMP=no
mv cnvnator ../bin
mv cnvnator2VCF.pl ../bin
cd $WD
rm -r tools/cnvnator/2018-07-09/src

# Installing Picard
mkdir -p tools/picard/2.12.1
cd tools/picard/2.12.1
wget -q https://github.com/broadinstitute/picard/releases/download/2.12.1/picard.jar
cd $WD

# Installing GATK
mkdir -p tools/gatk/3.7-0
cd tools/gatk/3.7-0
url='https://software.broadinstitute.org/gatk/download/auth?package=GATK-archive&version=3.7-0-gcfedb67'
wget -O GenomeAnalysisTK-3.7-0-gcfedb67.tar.bz2 "$url"
tar xjf GenomeAnalysisTK-3.7-0-gcfedb67.tar.bz2 && rm GenomeAnalysisTK-3.7-0-gcfedb67.tar.bz2
cd $WD
