LOKALISE_TOKEN=$1

lokalise2 --token $LOKALISE_TOKEN --project-id 961497065ee6ad1e440843.11368444 file download --format strings --dest ../temp --unzip-to ../temp/locales

for directory in `find ../temp/locales -type d`
do
	if [[ "$directory" == '../temp/locales' ]]; then
		continue
	fi

	#get the language code to match iOS naming
	language="$(basename "$directory")"
	language=${language/.lproj/}
	#if italian or greek remove anything after the -
	if [[ "$language" == 'it-IT' || "$language" == 'el-GR' ]]; then
		language=${language//\-[a-zA-z]*/}
	fi

    
    echo "parsing directory $directory"
    for file in `find $directory/*.strings`; do
    	
    	filename="$(basename "$file")"
    	
    	# ignore the Localizable and LaunchScreen files
    	if [[ "$filename" == 'LaunchScreen.strings' ]]; then
    		rm $file
			continue
		fi
		if [[ "$filename" == 'Localizable.strings' ]]; then
			continue
		fi

		if [[ "$filename" == 'InfoPlist.strings' ]]; then
			echo "Adding launch screen value to $language"
			echo -e "\"UILaunchStoryboardName\" = \"LaunchScreen_$language\";" >> $file
			continue
		fi

		echo "Contatenating $filename to Localizable.strings"

		cat "$file" >> "$directory/Localizable.strings"

		echo "Deleting $file"
		rm $file
	done

	echo "Done preparing files, starting copy"
	for file in `find $directory/*.strings`; do
		destinationFolder="../CovidSafe/$language.lproj"
		cp $file $destinationFolder
		echo "Copy files to project directory"
	done
done

rm -r ../temp/locales
