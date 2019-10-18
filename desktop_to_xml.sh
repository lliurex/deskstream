#!/bin/bash
#Script that generates xml info file from a desktop file
#Usage:
#Download lliurex-artwork-default from svn
#Download the sources of the package(s)
#Execute this script passing the dirs of sources to analyze as parameters
#Profit

msg_need_svn="In order to add the right icons you need to download lliurex-artwork-default from svn to the same dir as the source packages"
msg_dir_not_found="dir not found"
msg_icons_dir_error="Can't access %s or %s.\nSome icons may be missing.\n"
msg_select_file="Select one install file:\n"
msg_selected_file="\nSelected file: %s\n\n"
msg_select_dir="\nSelect the dir containing the desktop file:\n"
msg_gen_metainfo="Generating metainfo data path %s\n"
msg_parsing_desktop="Parsing %s\n"
msg_metainfo_generated="\nMetainfo file generated.\n"
msg_desktop_updated="\nDesktop file updated.\n"
msg_icon_found="Icon %s found.\nGenerating llx-resources dir\n"
msg_icon_not_found="\n********** WARNING!!!! **********\nNo icon named %s found on dirs %s, %s or %s\nRemember that the icon must be in SVG format and no in PNG or other image format\n *************************** \n"
msg_icon_location_info="\nPlease add %s as svg to %s and relaunch this program or use the llxsrc debhelper. Until then the app will not be included in our software store.\n"
msg_icon_exists="\nIcon package found on the right location. Checking if llxsrc helper exists in rules\n"
msg_work_done="\n----------\n\nWork done. If the process has no errors please check that the appfile.xml is right and that the rules file has the llxsrc helper. Also check that the icon is present in llx-resources.\nIn other case correct the errors and relaunch the script.\n\nRemember that the generated appfile.xml isn't a full one and is missing some fields like the screenshots. Take a cup of coffee and fulfill the empty fields following the specs at https://www.freedesktop.org/software/appstream/docs/sect-Metadata-Application.html\n\n"
msg_install_not_found="Install file not found in debian dir. Aborting.\n"
msg_select_workdir="Select the workdir\n"
msg_debhelper_enabled="package type llxsrc detected. Setting llx-resources as workdir\n"
msg_rules_old_format="\n********** WARNING!!!! **********\nrules file has an old format.\nIt's HIGHLY recommended to update it to the new rules format.\n *************************** \n"
msg_select_pkg="\nSelect the name of the package to process\n"
msg_desktop_not_found="\nDesktop file not found at %s. Looking at llx-resources\n"
msg_desktop_not_present="\nDesktop file was not found at %s. Operation aborted\n"
msg_searching_img="\nSearching screenshots in %s for %s\n"
msg_image_found="\nScreenshoot %s found for app %s\n"
function usage_help
{
	printf "Usage:\n"
	printf "$0 [svn_package_dir1] [svn_package_dir2]\n\n"
	printf "$msg_need_svn\n\n"
	exit 1
}

function analyze_zmd_dir
{
	printf "Analyzing $1\n"
	if [ ! -d $lliurexArtworkDir ] || [ ! -d $vibrancyArtworkDir ]
	then
		printf "$msg_icons_dir_error" $lliurexArtworkDir $vibrancyArtworkDir
	fi
	wrkDir=$rootDir"/"$srcDir
	cd $wrkDir
	baseMetainfoDir=${wrkDir}"/llx-resources/"
	zmdFiles=$(find . -name "*.app")
	for i in ${zmdFiles}
	do
		zmdName=$(basename $i)
		zmdName=${zmdName/.app/}
		zmdDir=$(dirname $i)
		cd $zmdDir
		metainfoDir=${baseMetainfoDir}"/"${zmdName}"/metainfo"
		fakeDesktopDir=${baseMetainfoDir}"/"${zmdName}"/desktops"
		mkdir $metainfoDir -p
		mkdir $fakeDesktopDir -p
		fakeDesktop=${fakeDesktopDir}"/"${zmdName}"_zmd.desktop"
		no_copy_desktop=1
		sw_zomando=1
		parse_desktop $metainfoDir $fakeDesktop ${zmdName}".app"
		cd $wrkDir
	done
	add_llxsrc_helper
}

function analyze_desktop_dir
{
	printf "Analyzing $1\n"
	if [ ! -d $lliurexArtworkDir ] || [ ! -d $vibrancyArtworkDir ]
	then
		printf "$msg_icons_dir_error" $lliurexArtworkDir $vibrancyArtworkDir
	fi
	
	cd $debianDir
	#Set the package name
	set_appName
	#Get the install file. If there're many choose one...
	declare -a installFiles
	count=0
	for i in *install
	do
		installFiles[$count]=$i
		let count++
	done
	index=0
	let count--
	if [[ ${installFiles[0]} = '*install' ]]
	then
		printf "$msg_install_not_found"
		get_workdir
	else
			echo "QUE VOY"
		if [ $count -gt 0 ]
		then
			printf "$msg_select_file"
			for i in `seq 0 ${count}`
			do
				printf "${i}) ${installFiles[$i]}\n"
			done
			printf "Select file [0]: "
			read index
			[ -z $index ] && index=0
			installFile=${installFiles[$index]}
		else
			installFile=${installFiles[0]}
		fi
		printf "$msg_selected_file" $installFile
		process_installFile ${installFile}
	fi
	add_llxsrc_helper
}

function set_appName
{
	appName=$(basename $pkgDir)
	declare -a pkgsArray
	count=0
	for pkg in `grep "Package:\ .*" control | cut -f2 -d ' '`
	do
		pkgsArray[$count]=$pkg
		let count++
	done
	let count--
	if [ $count -gt 0 ]
	then
		printf "$msg_select_pkg"
		for i in `seq 0 ${count}`
		do
			printf "$i) ${pkgsArray[$i]}\n"
		done
		printf "Select pkg name [0]: "
		read index
		[ -z $index ] && index=0
		appName=${pkgsArray[$index]}
	else
		installFile=${pkgsArray[0]}
	fi
}

function get_workdir
{
		cd $rootDir
		cd $srcDir
		if [ -d llx-resources ]
		then
			printf "$msg_debhelper_enabled"
			installDir="llx-resources"
		else
			printf "$msg_select_workdir"
			count=0
			declare -a dirArray
			for directory in *
			do
				dirArray[$count]=$directory
				let count++
			done
			printf "Selected Dir [0]: "
			read index
			installDir=${dirArray[$index]}
		fi
		process_pkg $installDir
}

function process_installFile
{
	installFile=$1
	echo "Cheking install file"
	if [ $(wc -l $installFile  | cut -f1 -d ' ') -gt 1 ]
	then 
		printf "$msg_select_dir"
		count=0
		declare -a fileLines
		while read -r dirLine
		do
			fileLines[$count]=$dirLine
			printf "$count) $dirLine\n"
			let count++
		done < ${installFile}
		printf "Selected file [0]: "
		read index
		installDir=${fileLines[$index]}
	else 
		installDir=`head -n1 $installFile`
	fi
	[ -z $index ] && index=0
	installDir=${installDir/\**/}
	[ -z "$installDir" ] && installDir='.'
	process_pkg $installDir
}

function process_pkg
{
	cd $rootDir"/"$srcDir
	wrkDir=`realpath $1 2>/dev/null`
	if [ $? -ne 0 ]
	then
		#Dir doesn't seems to exists. Find the desktop on $svnDir and ask about the action
		wrkDir='.'
		installDir='.'
	fi
	printf "Entering %s\n" $wrkDir
	if [ -d $wrkDir ]
	then
		cd $wrkDir
	else
		wrkDir=`dirname $wrkDir`
		installDir=$wrkDir
		cd $wrkDir
	fi
	#Find the desktop file of the application
	desktopFiles=$(find . -name "*.desktop")
	if [[ ! $desktopFiles ]]
	then
		printf "$msg_desktop_not_found" $wrkDir
		cd $rootDir"/"$srcDir
		wrkDir='.'
		installDir='.'
		desktopFiles=$(find . -name "*.desktop")
		if [[ ! $desktopFiles ]]
		then
			printf "$msg_desktop_not_present" $srcDir
			exit 1
		fi
	fi
	for desktopFile in $desktopFiles
	do
		cd $rootDir"/"$srcDir
		printf "Entering $wrkDir\n"
		cd $wrkDir
		#If workdir != $1 then it means that the install file has a file and not a dir
		#In this case we assume that the install is putting the desktop file so metainfoDir becames llx-resources directly
		if [[ $wrkDir != `realpath $1` ]]
		then
			metainfoDir=${rootDir}"/"${srcDir}"/llx-resources/"${appName}
		else
			metainfoDir=`dirname $desktopFile`
			metainfoDir=`dirname $metainfoDir`
		fi
		fakeDesktop=""
		metainfoDir=$metainfoDir"/metainfo"
		printf "$msg_gen_metainfo" $metainfoDir
		mkdir $metainfoDir -p
		fakeDesktop="none"
		parse_desktop $metainfoDir $fakeDesktop $desktopFile 
		iconName=$(grep ^Icon= $desktopFile)
		iconName=${iconName/*=/}
		iconName=${iconName/.*/}
		get_icon $iconName
	done
}

function parse_desktop
{
	metainfoDir=$1
	shift
	fakeDesktop=$1
	shift
	
	for desktopFile in $@
	do
		printf "$msg_parsing_desktop" $desktopFile
		item=`basename $desktopFile`
		get_screenshot $item
		if [ $sw_zomando -eq 1 ]
		then
		#generate a fake desktop 
			printf "generating fake desktop %s for zmd" $fakeDesktop
		fi

		awk -v processFile=$item -v metainfoDir=$metainfoDir -v screenshot=$imageFound -v zomando=$sw_zomando -v fakeDesktop=$fakeDesktop -F '=' '
		BEGIN{
			split(processFile,array,".",seps)
	#		revDomainName="net.lliurex."array[1]
			outFile="/tmp/"processFile
			printf("") > outFile
			xmlFile=metainfoDir"/"array[1]".appdata.xml"
			if (zomando==1)
			{
				tagId="<id>"array[1]"_zmd</id>" 
			} else {
				tagId="<id>"array[1]"</id>" 
			}

			split(array[1],arrayKey,"-",seps)
			for (nameIndex in arrayKey)
			{
				if (length(arrayKey[nameIndex])>=3)
				{
					if (tagKeywords!~">"arrayKey[nameIndex]"<")
						tagKeywords=tagKeywords"<keyword>"arrayKey[nameIndex]"</keyword>\n";
				}
			}
			execPrinted=0
			commentArrayIndex=1
			nameArrayIndex=1
			noGenerate=0
			process=1
			if (zomando==1)
			{
				print "[Desktop Entry]">fakeDesktop
				print "Type=zomando">>fakeDesktop
				fakeIcon=fakeDesktop
				gsub("_zmd.desktop", ".png", fakeIcon)
				n=split(fakeIcon,array,"/")

				print "Icon=/usr/share/banners/lliurex-neu/"array[n] >> fakeDesktop
				print "NoDisplay=true" >> fakeDesktop

			}
		}
		{
			if ($0~/^\[.*\]/)
			{
				if ($0~/\[Desktop.*/)
				{
					process=1;
				} else {
					process=0;
				}		
			}
			
			if (process==1)
			{
			 	if ($1~/^Name/) 
				{
				 	if ($1=="Name") 
					{
						tagName="<name>"
						lang=""
						if (zomando==1)
						{
							print $0>>fakeDesktop
						}
					} else {
						lang=$1
						split(lang,array,"[",seps)
						lang=substr(array[2], 1, length(array[2])-1)
						tagName="<name xml:lang=\""lang"\">"
					}
					tagName=tagName""$2"</name>"
					nameArray[nameArrayIndex]=tagName
					nameArrayIndex++;
					split($2,array," ",seps)
					if ( lang != "")
					{
						tagKeywords=tagKeywords"</keywords>\n<keywords xml:lang=\""lang"\">\n";
					}
					for (nameIndex in array)
					{
						if (length(array[nameIndex])>=3)
						{
							if (tagKeywords!~">"array[nameIndex]"<")
								tagKeywords=tagKeywords"<keyword>"array[nameIndex]"</keyword>\n";
						}
					}
					if (zomando)
						tagKeywords=tagKeywords"<keyword>Zomando</keyword>\n";
				} else if ($1~"Comment") {
					if ($1=="Comment")
					{
						tagSum="<summary>"
						tagDes="<p>"
					} else {
						lang=$1
						split(lang,array,"[",seps)
						lang=substr(array[2], 1, length(array[2])-1)
						tagSum="<summary xml:lang=\""lang"\">"
						tagDes="<p xml:lang=\""lang"\">"
					}
					sumario=$2
					split(sumario,array,".",seps)
					$0=$1"="array[1]
					summaryArray[commentArrayIndex]=tagSum""array[1]"</summary>"
					descriptionArray[commentArrayIndex]=tagDes""sumario"</p>"
					commentArrayIndex++
				} else if ($1=="Categories") {
					if (zomando==1)
					{
						print $0>>fakeDesktop
					}
					customCat=0
					countCat=0
					split($2,array,";",seps)
					for (catIndex in array)
					{
						if (array[catIndex]!="")
						{
							if (array[catIndex]~"-" && array[catIndex]!~"^X-")
							{
								customCat=1
								split(array[catIndex],lliurexCats,"-",seps)
								for (lliurexCatIndex in lliurexCats)
								{
									lliurexCat="<category>"lliurexCats[lliurexCatIndex]"</category>\n"lliurexCat
								}
								categoryArray[catIndex]=lliurexCat
							} else {
								categoryArray[catIndex]="<category>"array[catIndex]"</category>"
							}
							countCat++
						}
					}


					if (customCat==1 && countCat==1)
					{
						if (substr($0,length($0),1)==";")
							$0=$0"GTK"
						else
							$0=$0;"GTK"
						catIndex++
					}
				} else  if ($1=="Icon") {
					arrayItemNames=split($2,array,"/",seps)
					arrayItems=split(array[arrayItemNames],array,".",seps)
					iconBaseName=array[1]
					$0=$1"="iconBaseName
					if (zomando)
					{
						sub("zero-lliurex-", "",iconBaseName);
						tagIcon="<icon type=\"cached\">"iconBaseName"</icon>";
					} else {
						tagIcon="<icon type=\"stock\">"iconBaseName"</icon>";
					}
				} else if ($1=="Exec") {
					if (execPrinted==0)
					{
						split($2,array," ",seps)
						tagExec="<provides><binary>"array[1]"</binary></provides>"
						execPrinted=1
					}
				} else if ($1=="NoDisplay" || $1=="Terminal") {
					if ($2 == "true" || $2=="TRUE" || $2=="True")
					{
						noGenerate=1
					}
				}
			}
			print $0>>outFile
		}
		END{
			if (noGenerate==1)
			{
				print xmlFile" not generated as is a terminal app"
				exit 1
			}
			print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" > xmlFile
			print "<component type=\"desktop-application\">" >> xmlFile
			print tagId >> xmlFile
			print "<metadata_license>CC0-1.0</metadata_license>" >> xmlFile
			for (nameIndex in nameArray)
				print nameArray[nameIndex] >> xmlFile
			for (summaryIndex in summaryArray)
				print summaryArray[summaryIndex] >> xmlFile;
			print "<description>" >> xmlFile
			for (descriptionIndex in descriptionArray)
				print descriptionArray[descriptionIndex] >> xmlFile;
			print "</description>" >> xmlFile
			print "<categories>" >> xmlFile
			for (categoryIndex in categoryArray)
			{
				print categoryArray[categoryIndex] >> xmlFile;
			}
			if (zomando)
			{
				print "<category>Lliurex</category>" >> xmlFile
				print "<category>Zomando</category>" >> xmlFile
			}
			if (categoryIndex==0)
				print "<category>Utility</category>" >> xmlFile
			print "</categories>" >> xmlFile
			print tagIcon >> xmlFile
			print tagExec >> xmlFile
			print "<keywords>" >> xmlFile
			print tagKeywords >> xmlFile
			print "</keywords>" >> xmlFile
			if ( screenshot != 0 )
			{
				print "<screenshots>" >> xmlFile
				print "<screenshot type=\"default\">" >> xmlFile
				print "<caption>Main window.</caption>" >> xmlFile
				print "<image type=\"source\" width=\"800\" height=\"450\">"screenshot"</image>" >> xmlFile
				print "</screenshot>" >> xmlFile
				print "</screenshots>" >> xmlFile
			}
#			print "<developer_name>Lliurex Team</developer_name>" >> xmlFile
			print "</component>" >> xmlFile
		}
		' $desktopFile
		[ $? -eq 0 ] && printf "$msg_metainfo_generated"
		if [ -z $no_copy_desktop ]
		then
			cp /tmp/${item} $desktopFile
			printf "$msg_desktop_updated"
		fi
	done
}

function get_screenshot
{
	printf "$msg_searching_img" "debian" $1
	imageFound=0
	if [ $sw_zomando -ne 1 ]
	then
		pkgName=${1/.desktop/}
	else
		pkgName=${1/.app/}
		pkgName=${pkgName/*-/}
	fi
	url="https://screenshots.debian.net/packages?page=1&search=${pkgName}&utf8=✓"
	get_screenshot_from $url $pkgName
#	if [[ $imageFound == 0 ]]
#	then
#		printf "$msg_searching_img" "ubuntu"
#		url="http://screenshots.ubuntu.com/packages?page=1&search=${pkgName}&utf8=✓"
#		get_screenshot_from $url $pkgName
#	fi
	if [[ $imageFound ==  'https://screenshots.debian.net/' || $imageFound == ' https://screenshots.ubuntu.com/' ]]
	then
		printf "Discarting image...\n"
		imageFound=0
	fi

}

function get_screenshot_from
{
	url=$1
	baseUrl=${url/packages*/}
	pkgName=$2
	outFile=$(mktemp)
	wget $url -t 2 -T 10 -o /dev/null -O $outFile
	if [ $? -eq 0 ]
	then
		searchResult=$(grep  -P -o  "href=\"\/package\/".*?\" $outFile | head -n1)
		if [ $searchResult ]
		then
			searchResult=${searchResult/href=\"\//}
			searchResult=${searchResult/\"/}
			url=${baseUrl}${searchResult}
			wget $url -t 2 -T 10 -o /tmp/wget_desktop.log -O $outFile
			if [ $? -eq 0 ]
			then
				imageFound=$(grep  -P -o  "href=\"\/screenshots\/".*?\" $outFile | head -n1)
				imageFound=${imageFound/href=\"\//}
				imageFound=${imageFound/\"/}
				imageFound=${baseUrl}${imageFound}
				printf "$msg_image_found" $imageFound $pkgName
			fi
		fi
	fi
}

function get_icon
{
	[ -z ${1} ] && echo "No icon selected" && return
	iconName=$(basename $1)
	#Check if a svg icon exists
	workDir=$PWD
	printf "\nSearching for icon ${iconName}.svg in our package\n"
	#First we'll check the dir for resources
	resourcesDir=llx-resources/
	cd $rootDir
	cd $srcDir
	iconFile=$(find ${resourcesDir} -name "$iconName.svg" | grep icons)
	if [[ ! $iconFile ]]
	then
		cd $workDir
		printf "Entering $workDir\n"
		iconPath=${srcDir}"/"${installDir}
		iconFile=$(find . -name "$iconName.svg")
		if [[ ! $iconFile ]]
		then
			printf "Accesing %s" `realpath $lliurexArtworkDir`
			#Look for the svg in lliurex-theme
			cd $rootDir
			iconPath=$lliurexArtworkDir
			cd $lliurexArtworkDir
			iconFile=$(find . -name "${iconName}.svg")
		fi
		if [[ $iconFile ]]
		then
			iconFile=$(realpath $iconFile)
			cd $rootDir
			printf "$msg_icon_found" $iconFile
			cd $srcDir
			resourcesDir="llx-resources/"${appName}"/icons/apps/"
			mkdir $resourcesDir -p
			cd $OLDPWD
			cp ${iconFile} ${srcDir}"/"${resourcesDir}
			cd $OLDPWD
		else
			printf "$msg_icon_not_found" ${iconName} "$lliurexArtworkDir" "$resourcesDir" "$installDir"
			printf "$msg_icon_location_info" ${iconName} "$lliurexArtworkDir" 
		fi
	else
		printf "$msg_icon_exists"
	fi
}

function add_llxsrc_helper
{
	cd $rootDir
	cd $debianDir
	printf "Adding llxsrc to rules"
	if [[ ! `grep 'llxsrc' rules` ]]
	then
		if [[ `grep 'dh \$@' rules` ]]
		then
			if [[ `grep '\-\-with' rules` ]]
			then 
				sed -i 's/\(dh $@\ --with\ \)/\0llxsrc,/' rules
			else
				sed -i 's/\(dh $@\ \)/\0 --with\ llxsrc\ /' rules
			fi
		else
			printf "$msg_rules_old_format"
			sed -i 's/\tdh_installdeb/\tdh_llxsrcinstall\n\tdh_installdeb/' rules
		fi
	fi

	if [[ ! `grep 'llxsrchelper' control` ]]
	then
		sed -i 's/\(Build-Depends:\ \)/\0llxsrchelper,/' control
	fi
}

function get_package_type
{
	cd $srcDir
	[[ $(find . -name "*zmd") ]] && echo "zmd" || echo "deb"
}

### MAIN PROGRAM ###

[[ $@ ]] || usage_help

for parm in $@
do
	if [ ! -d $parm ]
	then
		printf "\n${parm}: $msg_dir_not_found\n"
		usage_help
		exit 1
	fi
done

launchDir=`realpath $PWD`

for parm in $@
do
	cd $launchDir
	rootDir=$launchDir
	svnDir=`realpath $parm`
	pkgDir=`realpath $parm`
	srcDir=${parm}"/trunk/fuentes"
	debianDir=${parm}"/trunk/fuentes/debian"
	lliurexArtworkDir=${svnDir}"/../vibrancy-colors/trunk/fuentes/vibrancy-lliurex/apps"
	no_copy_desktop=""
	sw_zomando=0
	[ $(get_package_type) == 'zmd' ]  && analyze_zmd_dir $parm || analyze_desktop_dir $parm
done

printf "$msg_work_done"

exit 0

