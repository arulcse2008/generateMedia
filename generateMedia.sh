#!/bin/bash
#set -x

# Media info parameters
mediaHeader=('General Complete name' 'General File Type' 'General Format' 'General Format profile' 'General Format Info' \
	 'General Codec ID' 'General File size' 'General Duration' 'General Overall bit rate mode' \
	 'General Overall bit rate' 'General Encoded date' 'General Tagged date' 'Image Format' \
	 'Image Format/Info' 'Image Format_Compression' 'Image Width' 'Image Height' 'Image Bit depth' \
	 'Image Color space' 'Image Chroma subsampling' 'Image Compression mode' 'Image Stream size' \
	 'Video ID' 'Video Format' 'Video Format/Info' 'Video Format profile' 'Video Format settings' \
	 'Video Format settings, CABAC' 'Video Format settings, ReFrames' 'Video Codec ID' \
	 'Video Codec ID/Info' 'Video Duration' 'Video Bit rate' 'Video Width' 'Video Height' \
	 'Video Display aspect ratio' 'Video Frame rate mode' 'Video Frame rate' 'Video Color space' \
	 'Video Chroma subsampling' 'Video Bit depth' 'Video Scan type' 'Video Bits/(Pixel*Frame)' \
	 'Video Stream size' 'Video Writing library' 'Video Encoding settings' \
	 'Video Encoded date' 'Video Tagged date' 'Video Color range' 'Video Color primaries' \
	 'Video Transfer characteristics' 'Video Matrix coefficients' 'Audio ID' \
	 'Audio Format' 'Audio Format/Info' 'Audio Format profile' 'Audio Codec ID' 'Audio Duration' \
	 'Audio Bit rate mode' 'Audio Bit rate' 'Audio Channel(s)' 'Audio Channel positions' \
	 'Audio Sampling rate' 'Audio Frame rate' 'Audio Compression mode' 'Audio Stream size' \
	 'Audio Writing library' 'Audio Encoding settings' 'Audio Default' 'Audio Forced' \
	 'Audio Encoded date' 'Audio Tagged date')

#Values are derived from mediaHeader
FILE_NAME=0
MEDIA_TYPE=1
MEDIA_FORMAT=2

#Image related macros
IMAGE_FORMAT=2
IMAGE_FORMAT_COMPRES=13
IMAGE_WIDTH=14
IMAGE_HEIGHT=15
IMAGE_BIT_DEPTH=16
IMAGE_COLOR_SPACE=17
IMAGE_COMPRES_MODE=19

#Video related macros
VIDEO_CODEC_ID=28
VIDEO_DURATION=30
VIDEO_BITRATE=31
VIDEO_WIDTH=32
VIDEO_HEIGHT=33
VIDEO_ASPECT_RATIO=34
VIDEO_FRAME_RATE=36
VIDEO_COLOR_SPACE=37
VIDEO_BIT_DEPTHS=39

#Audio related macros
AUDIO_
AUDIO_
AUDIO_
AUDIO_
AUDIO_
AUDIO_
AUDIO_
AUDIO_


declare  mediaData
declare  mediaCommand

#Check whether the ffmpeg is installed in the system or not?
which ffmpeg > /dev/null
if [ $? != 0 ]
then
	echo "ffmpeg utility is missing, Kindly install them using 'sudo apt-get install ffmpeg'"
	exit 1
fi

#function to print usage
usage ()
{
    echo "Usage: $0 -m <mediaInfo.csv> -i <Input reference media>"
    echo "eg: $0 -m mediaDetails.csv -i ReferenceVideo.mp4"
    exit 1
}

printVideoParams ()
{
}


printAudioParams ()
{
}

printImageParams ()
{
}

#Values are derived from mediaHeader
FILE_NAME=0
MEDIA_TYPE=1
MEDIA_FORMAT=2

generateMedia ()
{
	#Collect all the elements from the file and take action accordingly
	metaMedia=("$@")

	#getting the only filename from the the completename
	fileName=$(basename "${metaMedia[$FILE_NAME]}")

	#check the mediatype
	case ${metaMedia[$MEDIA_TYPE]} in
		"Image")
			echo "Input media is an image and name $fileName"
			printImageParams "${metaMedia[@]}"
			;;
		"Audio")
			echo "Input media is an audio and name $fileName"
			printAudioParams "${metaMedia[@]}"
			;;
		"Video")
			echo "Input media is an video and name $fileName"
			
			printVideoparams "${metaMedia[@]}"
			;;
		*)
		echo "Invalid media type and name $fileName"
		return
	esac
}

#check input arguments
if [ $# != 4 ];
then
	usage
fi

#validate media file availability
if [ $1 != "-m" ]
then
	echo "Invalid arguments $1"
	usage
fi

if [ ! -f $2 ]
then
	echo "File $2 is not found, Please check the file name or path"
	usage
fi

if [ $3 != "-i" ];
then
	echo "Invalid arguments $1"
	usage
fi

if [ ! -f $4 ]
then
	echo "Media Reference File $4 is not found, Please check the file name or path"
	usage
fi

fileCount=0
declare mediaHeaderArr

#deleting backups
rm -fr output_old

#backup previous results
mv output output_old

#creating directory to store files
mkdir output

#Processing mediaInfo file
while read -r eachMediaRow
do
	#Check whether header is matching with input media file
	#delimiter is "\t"
	#reading input file header and converting into array to compare the headers
	IFS=$'\t' read -a mediaHeaderArr <<< "$eachMediaRow"

	row=0
	if [ $fileCount -eq 0 ];
	then
		#dumping data into the row for the file
		for eachColumn in "${mediaHeader[@]}"; do
			if [ "$eachColumn" != "${mediaHeaderArr[$row]}" ]
			then
				echo "Input mediaInfo file Header mismatched"
				exit 1
			fi
			row=$((row+1))
		done
	else
		#Processing mediainfo one by one
		generateMedia "${mediaHeaderArr[@]}"
	fi

	fileCount=$((fileCount+1))
done < $2
echo "Generating media files are completed for $fileCount files. Files are generated under $PWD/output directory"
exit 0
