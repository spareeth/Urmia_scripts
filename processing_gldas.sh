#!/bin/sh
#process different variables from gldas datasets
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

INDAT="/mnt/rawdata/mashhad_phase2/GLDAS/input"
OUTDAT="/mnt/rawdata/urmia/scripts"
g.region vect=egypt_bound res=0.25 -a
#g.region n=37.219 s=35.394 w=58.166 e=61.494 res=0.25 -a
cd ${INDAT}
for yy in `seq 2013 2014`; do
	cd ${INDAT}/${yy}
	leap=`is_leap_year $yy`
	if [ $leap -eq 1 ]; then
		nd=366
	else
		nd=365
	fi
	for d in `seq 1 $nd`; do
		doy=`echo $d | awk '{ printf("%03d\n", $1) }'`
		dd=`doy2date ${yy} ${doy}|cut -d- -f3`
		mm=`doy2date ${yy} ${doy}|cut -d- -f2`
		cd ${INDAT}/${yy}/${doy}
		for i in `ls GLDAS*.nc4`; do
			dt=`echo ${i}|cut -d. -f2-3`
			gdal_translate NETCDF:"${i}":Qair_f_inst GLDAS_NOAH025_3H_${dt}_Qair.tif
			gdal_translate NETCDF:"${i}":Psurf_f_inst GLDAS_NOAH025_3H_${dt}_Psurf.tif
			gdal_translate NETCDF:"${i}":Tair_f_inst GLDAS_NOAH025_3H_${dt}_Tair.tif
			gdal_translate NETCDF:"${i}":Wind_f_inst GLDAS_NOAH025_3H_${dt}_Wind.tif
			gdal_translate NETCDF:"${i}":SWdown_f_tavg GLDAS_NOAH025_3H_${dt}_SWdown.tif
			## Import to GRASS
			r.in.gdal in=GLDAS_NOAH025_3H_${dt}_Qair.tif out=GLDAS_NOAH025_3H_${dt}_Qair -o
			r.in.gdal in=GLDAS_NOAH025_3H_${dt}_Psurf.tif out=GLDAS_NOAH025_3H_${dt}_Psurf -o			
			r.in.gdal in=GLDAS_NOAH025_3H_${dt}_Tair.tif out=GLDAS_NOAH025_3H_${dt}_Tair -o
			r.in.gdal in=GLDAS_NOAH025_3H_${dt}_Wind.tif out=GLDAS_NOAH025_3H_${dt}_Wind -o
			r.in.gdal in=GLDAS_NOAH025_3H_${dt}_SWdown.tif out=GLDAS_NOAH025_3H_${dt}_SWdown -o
			## Air temperature
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_Tair = GLDAS_NOAH025_3H_${dt}_Tair - 273.15"
			## Short wave radiation
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_SWdown = GLDAS_NOAH025_3H_${dt}_SWdown"
			## Wind speed
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_Wind = GLDAS_NOAH025_3H_${dt}_Wind"
			## Pressure convert from pa to mb
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_Psurf = GLDAS_NOAH025_3H_${dt}_Psurf / 100"
			## Humidity according to the url: https://earthscience.stackexchange.com/questions/2360/how-do-i-convert-specific-humidity-to-relative-humidity
			r.mapcalc "es = 6.112 * exp((17.67 * GLDAS_NOAH025_3H_${dt}_Tair) / (GLDAS_NOAH025_3H_${dt}_Tair + 243.5))" --o
			r.mapcalc "e = (GLDAS_NOAH025_3H_${dt}_Qair * GLDAS_NOAH025_3H_${dt}_Psurf) / (0.378 * GLDAS_NOAH025_3H_${dt}_Qair + 0.622)"
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_Rh = (e / es) * 100"
			r.mapcalc "GLDAS_NOAH025_3H_${dt}_Rh = float(if(GLDAS_NOAH025_3H_${dt}_Rh > 100, 100, if(GLDAS_NOAH025_3H_${dt}_Rh < 0, 0, GLDAS_NOAH025_3H_${dt}_Rh)))"
		done
		r.series input="GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0600_Tair,GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0900_Tair" output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_inst method=average
		r.series input="GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0600_SWdown,GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0900_SWdown" output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_inst method=average
		r.series input="GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0600_Wind,GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0900_Wind" output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_inst method=average
		r.series input="GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0600_Rh,GLDAS_NOAH025_3H_A${yy}${mm}${dd}.0900_Rh" output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_inst method=average
		MAPS1=`g.list rast pattern=GLDAS_NOAH025_3H_A${yy}${mm}${dd}.*_Tair$ sep=, map=.|cat`
		MAPS2=`g.list rast pattern=GLDAS_NOAH025_3H_A${yy}${mm}${dd}.*_SWdown$ sep=, map=.|cat`
		MAPS3=`g.list rast pattern=GLDAS_NOAH025_3H_A${yy}${mm}${dd}.*_Wind$ sep=, map=.|cat`
		MAPS4=`g.list rast pattern=GLDAS_NOAH025_3H_A${yy}${mm}${dd}.*_Rh$ sep=, map=.|cat`
		r.series input=${MAPS1} output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_24 method=average
		r.series input=${MAPS2} output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_24 method=average
		r.series input=${MAPS3} output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_24 method=average
		r.series input=${MAPS4} output=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_24 method=average
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_inst out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_inst.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_24 out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Tair_24.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_inst out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_inst.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_24 out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_SWdown_24.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_inst out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_inst.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_24 out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Wind_24.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_inst out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_inst.tif
		r.out.gdal in=GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_24 out=${OUTDAT}/GLDAS_NOAH025_3H_A${yy}${mm}${dd}_Rh_24.tif
		echo "${yy} ${mm} ${dd} done"
	done
	echo "${yy} done"
done
