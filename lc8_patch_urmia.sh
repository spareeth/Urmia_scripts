#!/bin/sh
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
	## Now patching to path bbox
	g.region vect=path${PTH}_bnd res=30 -a
	MAPS1=`g.list rast pattern=*${t}*BQA|tr '\n' ','  | sed 's+,$+\n+g'`
	MAPS1CNT=`g.list rast pattern=*${t}*BQA|wc -l`
	OUT1="${SEN}_L1TP_p${PTH}_patch_${t}_T1_BQA"
	if [ ${MAPS1CNT} -eq 1 ]; then
		r.mapcalc "${OUT1} = ${MAPS1}"
	else
		r.patch input=${MAPS1} output=${OUT1}
	fi
	r.out.gdal in=${OUT1} out=${OUTDIR}/${DIR}/${OUT1}.TIF nodata=0 --o -f
	MAPS2=`g.list rast pattern=*${t}*cloud_Mask|tr '\n' ','  | sed 's+,$+\n+g'`
	MAPS2CNT=`g.list rast pattern=*${t}*cloud_Mask|wc -l`
	OUT2="${SEN}_L1TP_p${PTH}_patch_${t}_T1_cloud_Mask"
        if [ ${MAPS2CNT} -eq 1 ]; then
                r.mapcalc "${OUT2} = ${MAPS2}"
        else
                r.patch input=${MAPS2} output=${OUT2}
        fi
	r.out.gdal in=${OUT2} out=${OUTDIR}/${DIR}/${OUT2}.TIF nodata=0 --o -f
	MAPS3=`g.list rast pattern=*${t}*snow_Mask|tr '\n' ','  | sed 's+,$+\n+g'`
	MAPS3CNT=`g.list rast pattern=*${t}*snow_Mask|wc -l`
	OUT3="${SEN}_L1TP_p${PTH}_patch_${t}_T1_snow_Mask"
        if [ ${MAPS3CNT} -eq 1 ]; then
                r.mapcalc "${OUT3} = ${MAPS3}"
        else
                r.patch input=${MAPS3} output=${OUT3}
        fi
	r.out.gdal in=${OUT3} out=${OUTDIR}/${DIR}/${OUT3}.TIF nodata=0 --o -f
	for i in 1 2 3 4 5 6 7 9 10 11; do
		MAPS=`g.list rast pattern=*${t}*B${i}|tr '\n' ','  | sed 's+,$+\n+g'`
		MAPSCNT=`g.list rast pattern=*${t}*B${i}|wc -l`
		OUT="${SEN}_L1TP_p${PTH}_patch_${t}_T1_B${i}"
	        if [ ${MAPSCNT} -eq 1 ]; then
         	       r.mapcalc "${OUT} = ${MAPS}"
	        else
        	       r.patch input=${MAPS} output=${OUT}
	        fi
		r.out.gdal in=${OUT} out=${OUTDIR}/${DIR}/${OUT}.TIF nodata=0 --o -f
	done
	r.composite red=${SEN}_L1TP_p${PTH}_patch_${t}_T1_B5 green=${SEN}_L1TP_p${PTH}_patch_${t}_T1_B4 blue=${SEN}_L1TP_p${PTH}_patch_${t}_T1_B3 output=${SEN}_L1TP_p${PTH}_patch_${t}_T1_comp
	g.remove type=rast pattern=LC08* exclude="*patch*" -f
	g.remove type=rast pattern=LC08* exclude="*patch*" -f
	g.remove type=rast pattern=LE07* exclude="*patch*" -f
	g.remove type=rast pattern=LE07* exclude="*patch*" -f
	cd ${INDIR}
done
