#!/bin/bash
set -x
#Samples
#
# convert from vob to avi with mpeg4 codec supports
#ffmpeg -i snatch_1.vob -f avi -c:v mpeg4 -b:v 800k -g 300 -bf 2 -c:a libmp3lame -b:a 128k snatch.avi
#

# TODO
# Limitations
# 10 bit videos are not supported
# only support yuv encoded videos so far


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
	 'Audio Bit depth' 'Audio Writing library' 'Audio Encoding settings' 'Audio Default' 'Audio Forced' \
	 'Audio Encoded date' 'Audio Tagged date')

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

inputRefMedia=$4

fileCount=0
declare mediaHeaderArr

#deleting backups
rm -fr output_old

#backup previous results
mv -f output output_old

#creating directory to store files
mkdir -p output

#MACRO Definitions (Values are derived from mediaHeader)
#General Macros
MINTOSECOND=60
SECONDTOMILLISECOND=0.001
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
VIDEO_FORMAT=29
VIDEO_DURATION=31
VIDEO_BITRATE=32
VIDEO_WIDTH=33
VIDEO_HEIGHT=34
VIDEO_ASPECT_RATIO=35
VIDEO_FRAME_RATE=37
VIDEO_COLOR_SPACE=38
VIDEO_CHROMA_SUBSAMPLING=39
VIDEO_BIT_DEPTHS=40

#Audio related macros
AUDIO_FORMAT=52
AUDIO_DURATION=57
AUDIO_BIT_RATE=59
AUDIO_CHANNELS=60
AUDIO_SAMPLING_RATE=61
AUDIO_BIT_DEPTH=65

#Arrays of meta details, meta headers
declare mediaData
declare metaMedia
declare mediaCommand

#General Parameters
fileName=""

#Video Parameters
videoCodecId=""
videoFormat=""
videoDuration=""
videoBitRate=""
videoWidth=""
videoHeight=""
videoAspectRatio=""
videoFrameRate=""
videoColorSpace=""
videoBitDepth=""
videoChromaSubSampling=""

#Audio Parameters
audioBitRate=""
audioFormat=""
audioDuration=""
audioChannels=""
audioSamplingRate=""
audioBitDepth=""

#Image Parameters
imageFormat=""
imageFormatCompres=""
imageWidth=""
imageHeight=""
imageBitDepth=""
imageColorspace=""
imageCompresMode=""

getVideoParams ()
{
	milliseconds=""
	seconds=""
	minutes=""
	#-c:v "codec name" should be used
	videoCodecId=${metaMedia[VIDEO_CODEC_ID]}

	#videoFormat -f "avc" should be used
	videoFormat=${metaMedia[VIDEO_FORMAT]}

	#-t should be used with seconds
	if [[ ${metaMedia[VIDEO_DURATION]} =~ "min" ]];
	then
		milliseconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}'|awk -F "ms" '{print $1}')
		seconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		minutes=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $1}')
		videoDuration=`expr $minutes \* $MINTOSECOND + $seconds + $milliseconds \* $SECONDTOMILLISECOND`
	else
		milliseconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}'|awk -F "ms" '{print $1}')
		seconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		videoDuration=`expr $seconds + $milliseconds \* $SECONDTOMILLISECOND`
	fi

	#increment one second for rounding off
	videoDuration=$(($videoDuration+1))

	#figure out the bitrate of the video
	videoBitRate=$(echo ${metaMedia[VIDEO_BITRATE]}|tr -d ' '|awk -F "b/s" '{print $1}')

	#scaling resolutions -vf scale=1920:1080
	videoWidth=$(echo ${metaMedia[VIDEO_WIDTH]}|awk -F "pixels" '{print $1}' |tr -d ' ')
	videoHeight=$(echo ${metaMedia[VIDEO_HEIGHT]}|awk -F "pixels" '{print $1}' |tr -d ' ')

	#-aspect should be used "-aspect 16:9" or "-aspect 4:3"
	videoAspectRatio=${metaMedia[VIDEO_ASPECT_RATIO]}

	#-r should be used -r 24 (for 24fps)
	if [[ ${metaMedia[VIDEO_FRAME_RATE]} =~ "(" ]];
	then
		videoFrameRate=$(echo ${metaMedia[VIDEO_FRAME_RATE]}|tr -d ' '|awk -F "(" '{print $1}')
	else
		videoFrameRate=$(echo ${metaMedia[VIDEO_FRAME_RATE]}|tr -d ' '|awk -F "FPS" '{print $1}')
	fi


	#assign only lower case for yuv
	#TODO need to check for colorspace apart from  yuv
	videoColorSpace=${metaMedia[VIDEO_COLOR_SPACE],,}

	#convert 4:2:2 to 422
	if [ ${metaMedia[VIDEO_CHROMA_SUBSAMPLING]} = "0" ]
	then
		videoChromaSubSampling="NA"
	else
		videoChromaSubSampling=$(echo ${metaMedia[VIDEO_CHROMA_SUBSAMPLING]}|awk -F ":" '{print $1$2$3}')
	fi

	videoBitDepth=$(echo ${metaMedia[VIDEO_BIT_DEPTHS]}|awk -F "bits" '{print $1}'|tr -d ' ')

	audioBitRate=$(echo ${metaMedia[AUDIO_BIT_RATE]}|awk -F "b/s" '{print $1}'|tr -d ' ')
}

getAudioParams ()
{
	seconds=""
	milliseconds=""
	audioBitRate=$(echo ${metaMedia[AUDIO_BIT_RATE]}|awk -F "b/s" '{print $1}'|tr -d ' ')
	audioFormat=${metaMedia[AUDIO_FORMAT]}
#	audioDuration=$(echo ${metaMedia[AUDIO_DURATION]}|awk -F "s" '{print $1}'|tr -d ' ')
	#-t should be used with seconds
	echo ${metaMedia[AUDIO_DURATION]}
	if [[ ${metaMedia[AUDIO_DURATION]} =~ "min" ]];
	then
		seconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		minutes=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "min" '{print $1}')
		audioDuration=`expr $minutes \* $MINTOSECOND + $seconds + $milliseconds \* $SECONDTOMILLISECOND`
	else
		milliseconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "ms" '{print $1}'|awk -F "s" '{print $2}')
		seconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "s" '{print $1}')
		audioDuration=`expr $seconds + $milliseconds \* $SECONDTOMILLISECOND`
		echo $audioDuration $seconds $milliseconds $SECONDTOMILLISECOND
	fi

	audioChannels=$(echo ${metaMedia[AUDIO_CHANNELS]}|awk -F "channel" '{print $1}'|tr -d ' ')
	audioSamplingRate=$(echo ${metaMedia[AUDIO_SAMPLING_RATE]}|awk -F "kHz" '{print $1}'|tr -d ' ')
	audioBitDepth=$(echo ${metaMedia[AUDIO_BIT_DEPTH]}|awk -F "bits" '{print $1}'|tr -d ' ')
}

getImageParams ()
{
#Image Parameters
imageFormat=""
imageFormatCompres=""
imageWidth=""
imageHeight=""
imageBitDepth=""
imageColorspace=""
imageCompresMode=""

}

printVideoParams ()
{
	echo "Video parameters"
	echo "codect id:" $videoCodecId
	echo "videoFormat" $videoFormat
	echo "duration:" $videoDuration
	echo "bitrate:" $videoBitRate
	echo "Resolution:" $videoWidth"x"$videoHeight 
	echo "aspect ratio:"$videoAspectRatio
	echo "FPS:" $videoFrameRate
	echo "Bitdepth:" $videoBitDepth
	# TODO 10 bit videos are not supported
	echo "Colorspace:" $videoColorSpace
	echo "chromasubsampling:" $videoChromaSubSampling
}

printAudioParams ()
{
	echo "audio bitrate:" $audioBitRate
	echo "audio Format:" $audioFormat
	echo "audio duration:" $audioDuration
	echo "audio channels:" $audioChannels
	echo "audio sampling rate:" $audioSamplingRate
	echo "audio bit depth:" $audioBitDepth
}

printImageParams ()
{
	echo "I am dummy getAudioParams"
}

cmdToGenerateImage=""
cmdToGenerateAudio=""
cmdToGenerateVideo=""

generateImage ()
{
	cmdToGenerateImage=$(echo "ffmpeg -i" $inputRefMedia "-vf scale="$videoWidth":"$videoHeight "-r" $videoFrameRate "-aspect" $videoAspectRatio "-t" $videoDuration "-b:v" $videoBitRate "-b:a" $audioBitRate  "output/"$fileName)
	echo "executing ffmpeg cmd:" $cmdToGenerateImage
#	$cmdToGenerateImage
}

generateAudio ()
{
	cmdToGenerateAudio=$(echo "ffmpeg -i" $inputRefMedia "-t" $audioDuration "-b:a" $audioBitRate  "output/"$fileName)
	echo "executing ffmpeg cmd:" $cmdToGenerateAudio
#	$cmdToGenerateAudio
}

generateVideo ()
{
	if [ $videoChromaSubSampling = "NA" ]
	then
		#skip chroma and colorspace configuration, input file config will be taken
		cmdToGenerateVideo=$(echo "ffmpeg -i" $inputRefMedia "-vf scale="$videoWidth":"$videoHeight "-r" $videoFrameRate "-aspect" $videoAspectRatio "-t" $videoDuration "-b:v" $videoBitRate "-b:a" $audioBitRate  "output/"$fileName)
	else
		cmdToGenerateVideo=$(echo "ffmpeg -i" $inputRefMedia "-vf scale="$videoWidth":"$videoHeight "-pix_fmt "$videoColorSpace$videoChromaSubSampling"p" "-r" $videoFrameRate "-aspect" $videoAspectRatio "-t" $videoDuration "-b:v" $videoBitRate "-b:a" $audioBitRate  "output/"$fileName)
	fi

	echo "executing ffmpeg cmd:" $cmdToGenerateVideo
	$cmdToGenerateVideo
}

generateMedia ()
{
	#Collect all the elements from the file and take action accordingly
	metaMedia=("$@")

	#getting the only filename from the the completename
	fileName=$(basename "${metaMedia[$FILE_NAME]}")
	
	#check the mediatype
	echo "Input media type:  ${metaMedia[$MEDIA_TYPE]} and name $fileName"
	case ${metaMedia[$MEDIA_TYPE]} in
		"Image")
			#Get the Image parameters from each input field
			getImageParams

			#Print processed Image parameters
			printImageParams

			#Generate the Image files based on the processed input
			generateImage
			;;
		"Audio")
			#Get the Audio parameters from each input field
			getAudioParams

			#Print processed Audio parameters
			printAudioParams

			#Generate the Audio files based on the processed input
			generateAudio
			;;
		"Video")
			#Get the Video parameters from each input field
			getVideoParams

			#Print processed Video parameters
			printVideoParams

			#Generate the video files based on the processed input
			generateVideo
			;;
		*)
		echo "Invalid media type and name $fileName"
		return
	esac
}

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

	#To calculate the number of processed metadata
	fileCount=$((fileCount+1))
done < $2
echo "Generating media files are completed for $((fileCount-1)) files. Files are generated under $PWD/output directory"
exit 0
