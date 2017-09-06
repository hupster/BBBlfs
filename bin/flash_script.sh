#!/bin/bash

diff(){
	awk 'BEGIN{RS=ORS=" "}
		{NR==FNR?a[$0]++:a[$0]--}
		END{for(k in a)if(a[k])print k}' <(echo -n "${!1}") <(echo -n "${!2}")
}

is_file_exists(){
	local f="$1"
	[[ -f "$f" ]] && return 0 || return 1
}

is_online(){
	wget -q --tries=5 --timeout=20 http://google.com
	if [[ $? -eq 0 ]]; then
		return 0
	else
		return 1
	fi
}

usage(){
	echo "Usage: $0 [ debian | ubuntu | input.img.xz ]"
	echo "Supported images are just in .img.xz format."
	exit 1
}

echo
input=$1

if [[ $# -eq 0 ]]
then
	read -p "You did not provide an image to flash. Do you want me to download the latest Debian image from beagleboard.org? [yY]" -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
	then
		if ( ! is_online )
		then
			echo "You do not have network connectivity!"
			exit 1
		fi
		echo
		page="$(curl -s -O http://beagleboard.org/latest-images)" 
		line="$(cat latest-images | grep debian | head -n1)"
		url="$(echo $line | cut -c7-)"
		url="${url%?}"
		rm index.html
		rm latest-images
		wget -O flash.img.xz $url
		input="flash.img.xz"
	fi
else
	input=$1
fi

if ( ! is_file_exists usb_flasher)
then
	echo "Please make the project then execute the script!"
	exit 1
fi

if [ ! \( "$input" = "debian" -o "$input" = "ubuntu" \) ]
then

	if ( ! is_file_exists "$input" )
	then
		echo "Please provide an existing flash file."
		usage
		exit 1
	fi

	echo "Using image: $input"

fi
echo "Please do not insert any USB Sticks"\
		"or mount external hdd during the procedure."
echo 

read -p "When the BeagleBone Black is connected in USB Boot mode press [yY]." -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
	before=($(ls /dev | grep "sd[a-z]$"))
	
	sudo ./usb_flasher
	rc=$?
	if [[ $rc != 0 ]];
	then
		echo "Error putting the BeagleBone Black in USB Flasing mode."
		exit $rc
	fi

	echo -n "(4/5) Waiting for the BeagleBone Black to be mounted"
	for i in {1..20}
	do
		echo -n "."
		sleep 1
	done
	echo

	after=($(ls /dev | grep "sd[a-z]$"))
	bbb=($(diff after[@] before[@]))

	if [ -z "$bbb" ];
	then
		echo "Error detecting the BeagleBone Black as mass storage device."
		exit 1
	fi

	if [ ${#bbb[@]} != "1" ]
	then
		echo "You inserted an USB stick or mounted an external drive. Please "\
			"rerun the script without doing that."
		exit 1
	fi

	parts=($(ls /dev | grep "$bbb[1,2]"))
	for index in ${!parts[*]}
	do
		sudo umount /dev/${parts[$index]} > /dev/null 2>&1
	done

	echo "(5/5) Flashing image ..."

	if [ \( "$input" = "debian" -o "$input" = "ubuntu" \) ]
	then
		sudo ./bbb-armhf.sh $bbb $input
	else
		case ${input} in
			*.lzo )
			# handle lzo format
			lzop -dcf ${input} | sudo dd of=/dev/${bbb} bs=1M
			;;
			*.xz )
			# handle xz format
			xzcat ${input} | sudo dd of=/dev/${bbb} bs=1M
			;;
			* )
			# handle gz format
			gunzip -c ${input} | sudo dd of=/dev/${bbb} bs=1M
			;;
		esac
	fi

	sync

	echo "Done!"
	echo
fi
