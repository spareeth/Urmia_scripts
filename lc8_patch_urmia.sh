#!/bin/sh
## Author: Sajid Pareeth, 2018
## patch scenesin the ame path for the urmia and prepare for SEBAL input
## paths are 167,168,169
## tiles are 167 - 34,35; 168 - 33,34,35; 169 - 33,34
SEN="LC08"
PTH="168"
INDIR="/mnt/rawdata/urmia/input/satellite_data/missedones"
OUTDIR="/mnt/rawdata/urmia/input/satellite_data/ls_${PTH}_patch"
if [ -z "$GISBASE" ] ; then
    echo "You must be in GRASS GIS to run this program." >&2
    exit 1
fi
export GRASS_OVERWRITE=1
export GRASS_MESSAGE_FORMAT=plain  # percent output as 0..1..2..
# setting environment, so that awk works properly in all languages
unset LC_ALL
LC_NUMERIC=C
export LC_NUMERIC
cd ${INDIR}
# lc08_p${PTH}_dates_NW.csv
for t in `cat lc8_p168.csv`; do
	rm -f names.txt
	sh -c "/bin/ls -d ${SEN}*${t}_*/" >> names.txt
	for j in `cat names.txt`; do
		cd ${INDIR}/${j}
		r.mask -r
		SCN=`ls *BQA.TIF|cut -d_ -f1-7`
		r.in.gdal in=${SCN}_BQA.TIF out=${SCN}_BQA memory=2000
		g.region rast=${SCN}_BQA res=30 -a
		r.mapcalc "${SCN}_BQA = if(${SCN}_BQA == 1,null(),${SCN}_BQA)"
		i.landsat8.qc cloud="Maybe,Yes" cloud_shadow="Yes" cirrus="Yes" output=cloud_rules.txt --o
		i.landsat8.qc snow_ice="Yes" snow_ice="Yes" output=snow_rules.txt
		r.reclass input=${SCN}_BQA output=${SCN}_cloud_Mask rules=cloud_rules.txt
		r.reclass input=${SCN}_BQA output=${SCN}_snow_Mask rules=snow_rules.txt
		for i in 1 2 3 4 5 6 7 9 10 11; do
			r.in.gdal in=${SCN}_B${i}.TIF out=${SCN}_B${i} memory=2000
			r.mapcalc "${SCN}_B${i} = if(${SCN}_B${i} == 0,null(),${SCN}_B${i})" --o
		done
		r.composite red=${SCN}_B5 green=${SCN}_B4 blue=${SCN}_B3 output=${SCN}_comp
		for i in 1 2 3 4 5 6 7 9 10 11; do
			r.mask rast=${SCN}_cloud_Mask --o
			r.mapcalc "${SCN}_B${i} = ${SCN}_B${i}" --o
			r.mask rast=${SCN}_snow_Mask --o
			r.mapcalc "${SCN}_B${i} = ${SCN}_B${i}" --o
		done
	done
	r.mask -r
	DIR="${SEN}_L1TP_p${PTH}_patch_${t}_T1"
	mkdir -p ${OUTDIR}/${DIR}
	## Now patching to path bbo
