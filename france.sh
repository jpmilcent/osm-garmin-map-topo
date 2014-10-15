#!/bin/bash

# Generate for France a gmapsupp.img file to use with Garmin GPS
# It uses the OpenStreetMap data : http://www.openstreetmap.org/copyright
#
# Encoding : UTF-8
# Licence : GPL v2
# Copyright Jean-Pascal Milcent, 2014
# Dependances : java, mkgmap, splitter, osm-c-tools (osmconvert, osmupdate)

TIME_START=$(date +%s)
AREA="france"
AREA_NAME="France"
DIR_BASE=$(pwd)

# Functions
function ageEnSeconde {
	expr `date +%s` - `stat -c %Y $1`;
};

function displaytime {
	# Source : http://unix.stackexchange.com/questions/27013/displaying-seconds-as-days-hours-mins-seconds
	local T=$1
	local D=$((T/60/60/24))
	local H=$((T/60/60%24))
	local M=$((T/60%60))
	local S=$((T%60))
	[[ $D > 0 ]] && printf '%d days ' $D
	[[ $H > 0 ]] && printf '%d hours ' $H
	[[ $M > 0 ]] && printf '%d minutes ' $M
	[[ $D > 0 || $H > 0 || $M > 0 ]] && printf 'and '
	printf '%d seconds\n' $S
};

function download() {
	local url=$1
	local file=$2
	wget --progress=dot $url -O $file 2>&1 | grep --line-buffered -E -o "100%|[1-9]0%|^[^%]+$" | uniq
	echo -e "${Gra}Download $2 : ${Gre}DONE${RCol}"
};

# Load config
if [ -f ${DIR_BASE}/config.cfg ] ; then
	source ${DIR_BASE}/config.cfg
	echo -e "${Gra}Config : ${Gre}OK${RCol}"
else
	echo -e "\e[1;31mPlease configure the script by renaming the file 'config.defaut.cfg' to 'config.cfg.\e[0m"
	exit;
fi

# Install mkgmap & splitter
if [ ! -d "${DIR_APP}/mkgmap-r${MKGMAP_VERSION}" ] || [ ! -d "${DIR_APP}/splitter-r${SPLITTER_VERSION}" ] ; then
	echo -e "${Yel}Downloading and configuring Mkgmap & Splitter...${RCol}";
	cd ${DIR_APP}/
	if [ ! -d "${DIR_APP}/mkgmap-r${MKGMAP_VERSION}" ]; then
		rm -fR ${DIR_APP}/mkgmap-r*
		wget http://www.mkgmap.org.uk/download/mkgmap-r${MKGMAP_VERSION}.zip
		unzip mkgmap-r${MKGMAP_VERSION}.zip
		rm -f ${DIR_BIN}/mkgmap
		ln -s ${DIR_APP}/mkgmap-r${MKGMAP_VERSION} ${DIR_BIN}/mkgmap 
	fi
	if [ ! -d "${DIR_APP}/splitter-r${SPLITTER_VERSION}" ]; then
		rm -fR ${DIR_APP}/splitter-r*
		wget http://www.mkgmap.org.uk/download/splitter-r${SPLITTER_VERSION}.zip
		unzip splitter-r${SPLITTER_VERSION}.zip
		rm -f ${DIR_BIN}/splitter
		ln -s ${DIR_APP}/splitter-r${SPLITTER_VERSION} ${DIR_BIN}/splitter 
	fi
	cd ${DIR_BASE}
else
	echo -e "${Gra}Mkgmap r${MKGMAP_VERSION} & Splitter r${SPLITTER_VERSION} : ${Gre}OK${RCol}"
fi

# Check if the osm-c tools are needed
if [ ! -f ${DIR_BIN}/osmupdate ] || [ ! -f ${DIR_BIN}/osmconvert ] || [ ! -f ${DIR_BIN}/osmfilter ] ; then
	echo -e "${Yel}Downloading and building the osm-c tools...${RCol}";
	if [ ! -d "${DIR_APP}/c-tools" ]; then
		mkdir "${DIR_APP}/c-tools"
	fi
	
	cd "${DIR_APP}/c-tools"
	if [ ! -f ${DIR_APP}/c-tools/osmupdate ] ; then
		wget -O - http://m.m.i24.cc/osmupdate.c | cc -x c - -o osmupdate
		ln -s ${DIR_APP}/c-tools/osmupdate ${DIR_BIN}/osmupdate 
	fi
	if [ ! -f ${DIR_APP}/c-tools/osmconvert ] ; then
		wget -O - http://m.m.i24.cc/osmconvert.c | cc -x c - -lz -O3 -o osmconvert
		ln -s ${DIR_APP}/c-tools/osmconvert ${DIR_BIN}/osmconvert 
	fi
	if [ ! -f ${DIR_APP}/c-tools/osmfilter ] ; then
		wget -O - http://m.m.i24.cc/osmfilter.c |cc -x c - -O3 -o osmfilter
		ln -s ${DIR_APP}/c-tools/osmfilter ${DIR_BIN}/osmfilter 
	fi
	cd $DIR_BASE
else
	echo -e "${Gra}OSM C tools : ${Gre}OK${RCol}"
fi

# Maintain up to date the .osm.pbf file
if [ ! -f "${DIR_OSM}/${AREA}-latest.osm.pbf" ] ; then
	echo -e "${Yel}Downloading initial PBF file for area «${AREA}»...${RCol}";
	if [ $AREA == "france" ] ; then
		URL="http://download.geofabrik.de/europe/${AREA}-latest.osm.pbf"
	else
		URL="http://download.geofabrik.de/${AREA}-latest.osm.pbf"
	fi
	download $URL "${DIR_OSM}/${AREA}-latest.osm.pbf"
else
	# Check if an update has been made less than 20 hours
	if [ `ageEnSeconde "${DIR_OSM}/${AREA}-latest.osm.pbf"` -gt 72000 ] ; then
		echo -e "${Yel}Updating the PBF file for area «${AREA}»...${RCol}";
		#LAST_DATE=$(stat -c %y ${DIR_OSM}/${AREA}-latest.osm.pbf)
		#LAST_DATE=${LAST_DATE%% *}
		mv ${DIR_OSM}/${AREA}-latest.osm.pbf ${DIR_OSM}/${AREA}_old.osm.pbf
		${DIR_BIN}/osmupdate -v \
			-B=${DIR_POLY}/${AREA}.poly \
			-t=${DIR_TMP}/osmupdate \
			--keep-tempfiles \
			${DIR_OSM}/${AREA}_old.osm.pbf \
			${DIR_OSM}/${AREA}-latest.osm.pbf
		if [ $? -eq 21 ] ; then
			echo -e "${Yel}OSM file is already up-to-date. We rename the old file.${RCol}";
			mv "${DIR_OSM}/${AREA}_old.osm.pbf" "${DIR_OSM}/${AREA}-latest.osm.pbf"
		else
			rm -f "${DIR_OSM}/${AREA}_old.osm.pbf"
		fi
	else
		echo -e "${Gre}${AREA}-latest.osm.pbf is up to date${RCol}";
	fi
fi

# Convert the pbf file to o5m
echo -e "${Yel}Convert latest PBF file to o5m format...${RCol}";
if [ ! -f "${DIR_OSM}/${AREA}.o5m" ] || [ `ageEnSeconde "${DIR_OSM}/${AREA}.o5m"` -gt 72000 ] ; then
	if [ -f "${DIR_OSM}/${AREA}.o5m" ] ; then
		rm -f ${DIR_OSM}/${AREA}.o5m
	fi
	${DIR_BIN}/osmconvert --drop-version ${DIR_OSM}/${AREA}-latest.osm.pbf -o=${DIR_OSM}/france.o5m
fi

# Split the .o5m file for mkgmap
echo -e "${Yel}Splitting the o5m file for mkgmap...${RCol}";
cd ${DIR_MAP}
ls | grep -v '.gitignore' | xargs rm -f
java -Xmx${JAVA_XMX} -jar ${DIR_BIN}/splitter/splitter.jar \
 --mapid=53267593 \
 --mixed=yes \
 --max-nodes=5000000 \
 --output-dir=./splitter-out \
 --description="${AREA_NAME}" \
 ${DIR_OSM}/${AREA}.o5m > splitter.log

# Create the .img file with the o5m file split parts
echo -e "${Yel}Creating the gmapsupp.img file with mkgmap...${RCol}";
java -Xms${JAVA_XMX} -jar ${DIR_BIN}/mkgmap/mkgmap.jar -c ./splitter-out/template.args --gmapsupp

# Rename and save the gmapsupp.img file
if [ -f gmapsupp.img ] ; then
	mkdir -p ${DIR_IMG}/${AREA}
	DATE=`date +"%F"`
	mv gmapsupp.img ${DIR_IMG}/${AREA}/${DATE}_${AREA}.img
	echo -e "${Gre}You can find your img file here : ${DIR_IMG}/${AREA}/${DATE}_${AREA}.img ${RCol}";
else
	echo -e "${Red}gmapsupp.img file not found !${RCol}"
fi

# Show time elapsed
TIME_END=$(date +%s)
TIME_DIFF=$(($TIME_END - $TIME_START));
echo -e "${Whi}Total time elapsed : "`displaytime "$TIME_DIFF"`"${RCol}"
