#!/bin/bash
set -x
#
#Samples
# convert from vob to avi with mpeg4 codec supports
#ffmpeg -i snatch_1.vob -f avi -c:v mpeg4 -b:v 800k -g 300 -bf 2 -c:a libmp3lame -b:a 128k snatch.avi
#

# TODO
# Limitations
# 10 bit videos are not supported
# only support yuv encoded videos so far


# Media info parameters
mediaHeader=('General Complete name' 'General File Type' 'General Format' 'General Format profile' 'General Format Info'\
	 'General Codec ID' 'General File size' 'General Duration' 'General Overall bit rate mode'\
	 'General Overall bit rate' 'General Encoded date' 'General Tagged date' 'Image Format'\
	 'Image Format/Info' 'Image Format_Compression' 'Image Width' 'Image Height' 'Image Bit depth'\
	 'Image Color space' 'Image Chroma subsampling' 'Image Compression mode' 'Image Stream size'\
	 'Video ID' 'Video Format' 'Video Format/Info' 'Video Format profile' 'Video Format settings'\
	 'Video Format settings, CABAC' 'Video Format settings, ReFrames' 'Video Codec ID'\
	 'Video Codec ID/Info' 'Video Duration' 'Video Bit rate' 'Video Width' 'Video Height'\
	 'Video Display aspect ratio' 'Video Frame rate mode' 'Video Frame rate' 'Video Color space'\
	 'Video Chroma subsampling' 'Video Bit depth' 'Video Scan type' 'Video Bits/(Pixel*Frame)'\
	 'Video Stream size' 'Video Writing library' 'Video Encoding settings'\
	 'Video Encoded date' 'Video Tagged date' 'Video Color range' 'Video Color primaries'\
	 'Video Transfer characteristics' 'Video Matrix coefficients' 'Audio ID'\
	 'Audio Format' 'Audio Format/Info' 'Audio Format profile' 'Audio Codec ID' 'Audio Duration'\
	 'Audio Bit rate mode' 'Audio Bit rate' 'Audio Channel(s)' 'Audio Channel positions'\
	 'Audio Sampling rate' 'Audio Frame rate' 'Audio Compression mode' 'Audio Stream size'\
	 'Audio Bit depth' 'Audio Writing library' 'Audio Encoding settings' 'Audio Default' 'Audio Forced'\
	 'Audio Encoded date' 'Audio Tagged date' 'Text ID' 'Text Format' 'Text Codec ID'\
	 'Text Codec ID/Info' 'Text Duration' 'Text Bit rate' 'Text Count of elements' 'Text Stream size'\
	 'Text Title' 'Text Default' 'Text Forced')

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
    # TODO Include debug options by using loglevel
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
HOURTOSECOND=3600
SECONDTOMILLISECOND=0.001
FILE_NAME=0
MEDIA_TYPE=1
MEDIA_FORMAT=2

#Image related macros
IMAGE_FORMAT=2
IMAGE_FORMAT_COMPRES=14
IMAGE_WIDTH=15
IMAGE_HEIGHT=16
IMAGE_BIT_DEPTH=17
IMAGE_COLOR_SPACE=18
IMAGE_CHROMA_SUBSAMPLING=19
IMAGE_COMPRES_MODE=20

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
AUDIO_FORMAT=53
AUDIO_DURATION=57
AUDIO_BIT_RATE=59
AUDIO_CHANNELS=60
AUDIO_SAMPLING_RATE=62
AUDIO_FRAME_RATE=63
AUDIO_COMPRESS_MODE=64
AUDIO_BIT_DEPTH=66

#Subtitle related macros
TEXT_ID=73
TEXT_FORMAT=74
TEXT_CODEC_ID=75
TEXT_CODECID_INFO=76
TEXT_DURATION=77
TEXT_BITRATE=78
TEXT_COUNT_OF_ELEMENTS=79
TEXT_STREAM_SIZE=80
TEXT_TITLE=81
TEXT_DEFAULT=82
TEXT_FORCED=83

#Arrays of meta details, meta headers
declare mediaData
declare metaMedia
declare mediaCommand

#General Parameters
fileName=""
fileType=""

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
audioAvail=""

#Audio Parameters
audioBitRate=""
audioFormat=""
audioDuration=""
audioChannels=""
audioSamplingRate=""
audioBitDepth=""
audioCompresMode=""

#Image Parameters
imageFormat=""
imageFormatCompres=""
imageWidth=""
imageHeight=""
imageBitDepth=""
imageColorSpace=""
imageChromaSubSampling=""
imageCompresMode=""

#Text Parameters
textID=""
textFormat=""
textCodecID=""
textCodecIDInfo=""
textDuration=""
textBitRate=""
textCountOfElements=""
textStreamSize=""
textTitle=""
textDefault=""
textForced=""

getVideoParams ()
{
	milliseconds="0"
	seconds="0"
	minutes="0"
	hours="0"
	videoDuration="0"

	#-c:v "codec name" should be used
	videoCodecId=${metaMedia[VIDEO_CODEC_ID]}

	#videoFormat -f "avc" should be used
	videoFormat=${metaMedia[VIDEO_FORMAT]}

	#-t should be used with seconds
	if [[ ${metaMedia[VIDEO_DURATION]} =~ "h" ]];
	then
		minutes=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "h" '{print $2}'|awk -F "min" '{print $1}')
		hours=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "h" '{print $1}')
		videoDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+($hours*$HOURTOSECOND)"|bc`
	elif [[ ${metaMedia[VIDEO_DURATION]} =~ "min" ]];
	then
		seconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		minutes=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "min" '{print $1}')
		videoDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+$seconds"|bc`
	else
		milliseconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "ms" '{print $1}'|awk -F "s" '{print $2}')
		seconds=$(echo ${metaMedia[VIDEO_DURATION]}|tr -d ' '|awk -F "s" '{print $1}')
		videoDuration=`echo "scale=3; $seconds+($milliseconds*$SECONDTOMILLISECOND)"|bc`
	fi
	echo "ms $milliseconds s: $seconds ${metaMedia[VIDEO_DURATION]}"

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


	#TODO need to check for colorspace apart from  yuv
	#assign only lower case for yuv
	videoColorSpace=${metaMedia[VIDEO_COLOR_SPACE],,}

	#convert 4:2:2 to 422
	if [ ${metaMedia[VIDEO_CHROMA_SUBSAMPLING]} = "0" ];
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
	seconds="0"
	milliseconds="0"
	minutes="0"
	hours="0"
	audioDuration="0"

	if [[ ${metaMedia[AUDIO_DURATION]} = "0" || ${metaMedia[AUDIO_SAMPLING_RATE]} = "0" ]];
	then
		audioAvail="NO"
		echo "No Audio data"
		return
	else
		audioAvail="YES"
	fi

	audioBitRate=$(echo ${metaMedia[AUDIO_BIT_RATE]}|awk -F "b/s" '{print $1}'|tr -d ' ')

	audioFormat=${metaMedia[AUDIO_FORMAT]}

	if [[ ${metaMedia[AUDIO_DURATION]} =~ "h" ]];
	then
		minutes=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "h" '{print $2}'|awk -F "min" '{print $1}')
		hours=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "h" '{print $1}')
		audioDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+($hours*$HOURTOSECOND)"|bc`
	elif [[ ${metaMedia[AUDIO_DURATION]} =~ "min" ]];
	then
		seconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		minutes=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "min" '{print $1}')
		audioDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+$seconds"|bc`
	else
		milliseconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "ms" '{print $1}'|awk -F "s" '{print $2}')
		seconds=$(echo ${metaMedia[AUDIO_DURATION]}|tr -d ' '|awk -F "s" '{print $1}')
		audioDuration=`echo "scale=3; $seconds+($milliseconds*$SECONDTOMILLISECOND)"|bc`
	fi

	audioChannels=$(echo ${metaMedia[AUDIO_CHANNELS]}|awk -F "channel" '{print $1}'|tr -d ' ')
	audioSamplingRate=`echo "$(echo ${metaMedia[AUDIO_SAMPLING_RATE]}|awk -F "kHz" '{print $1}'|tr -d ' ')*1000"|bc`
	audioBitDepth=$(echo ${metaMedia[AUDIO_BIT_DEPTH]}|awk -F "bits" '{print $1}'|tr -d ' ')
}

getImageParams ()
{
	#Image Parameters
	imageFormat=${metaMedia[IMAGE_FORMAT]}
	imageFormatCompres=${metaMedia[IMAGE_FORMAT_COMPRES]}
	imageWidth=$(echo ${metaMedia[IMAGE_WIDTH]}|awk -F "pixels" '{print $1}' |tr -d ' ')
	imageHeight=$(echo ${metaMedia[IMAGE_HEIGHT]}|awk -F "pixels" '{print $1}' |tr -d ' ')
	imageBitDepth=$(echo ${metaMedia[IMAGE_BIT_DEPTH]}|awk -F "bits" '{print $1}'|tr -d ' ')
	#assign only lower case for yuv
	imageColorSpace=${metaMedia[IMAGE_COLOR_SPACE],,}

	#convert 4:2:2 to 422
	if [ ${metaMedia[IMAGE_CHROMA_SUBSAMPLING]} = "0" ]
	then
		imageChromaSubSampling="NA"
	else
		imageChromaSubSampling=$(echo ${metaMedia[IMAGE_CHROMA_SUBSAMPLING]}|awk -F ":" '{print $1$2$3}')
	fi

	imageCompresMode=${metaMedia[IMAGE_COMPRES_MODE]}
}

getTextParams ()
{
	milliseconds="0"
	seconds="0"
	minutes="0"
	hours="0"
	textDuration="0"

	echo "Text Duration: " ${metaMedia[TEXT_DURATION]}

	textID=${metaMedia[TEXT_ID]}

	textFormat=${metaMedia[TEXT_FORMAT]}

	textCodecID=${metaMedia[TEXT_CODEC_ID]}

	textCodecIDInfo=${metaMedia[TEXT_CODECID_INFO]}

	if [[ ${metaMedia[TEXT_DURATION]} =~ "h" ]];
	then
		minutes=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "h" '{print $2}'|awk -F "min" '{print $1}')
		hours=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "h" '{print $1}')
		textDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+($hours*$HOURTOSECOND)"|bc`
	elif [[ ${metaMedia[TEXT_DURATION]} =~ "min" ]];
	then
		seconds=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "min" '{print $2}'|awk -F "s" '{print $1}')
		minutes=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "min" '{print $1}')
		textDuration=`echo "scale=1; ($minutes*$MINTOSECOND)+$seconds"|bc`
	elif [[ ${metaMedia[TEXT_DURATION]} =~ "s" ]];
	then
		milliseconds=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "ms" '{print $1}'|awk -F "s" '{print $2}')
		seconds=$(echo ${metaMedia[TEXT_DURATION]}|tr -d ' '|awk -F "s" '{print $1}')
		textDuration=`echo "scale=3; $seconds+($milliseconds*$SECONDTOMILLISECOND)"|bc`
	else
		textDuration=0
	fi

	textBitRate=$(echo ${metaMedia[TEXT_BITRATE]}|awk -F "b/s" '{print $1}'|tr -d ' ')
	textCountOfElements=${metaMedia[TEXT_COUNT_OF_ELEMENTS]}
	textStreamSize=${metaMedia[TEXT_STREAM_SIZE]}
	textTitle=${metaMedia[TEXT_TITLE]}
	textDefault=${metaMedia[TEXT_DEFAULT]}
	textForced=${metaMedia[TEXT_FORCED]}
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
	echo "audio duration:" $audioDuration
	echo "audio channels:" $audioChannels
	echo "audio sampling rate:" $audioSamplingRate
	echo "audio CompresMode:" $audioCompresMode
	echo "audio bit depth:" $audioBitDepth
	echo "audio Format:" $audioFormat
}

printImageParams ()
{
	#Printing Image Parameters
	echo "image Format:" $imageFormat
	echo "image FormatCompres:" $imageFormatCompres
	echo "image Width:" $imageWidth
	echo "image Height:" $imageHeight
	echo "image BitDepth:" $imageBitDepth
	echo "image Colorspace:" $imageColorSpace
	echo "image CompresMode:" $imageCompresMode
}

printTextParams ()
{
	#Printing Text Parameters
	echo "Text ID:" $textID
	echo "Text Format:" $textFormat
	echo "Text Codec ID:" $textCodecID
	echo "Text Codec ID/Info:" $textCodecIDInfo
	echo "Text Duration:" $textDuration
	echo "Text Bit Rate:" $textBitRate
	echo "Text Count of elements:" $textCountOfElements
	echo "Text Stream Size:" $textStreamSize
	echo "Text Title:" $textTitle
	echo "Text Default:" $textDefault
	echo "Text Forced:" $textForced
}

cmdToGenerateImage=""
cmdToGenerateAudio=""
cmdToGenerateVideo=""
declare -A pixFmts=( ["1"]="monow" ["4"]="rgb4" ["8"]="rgb8" ["16"]="rgb565le" ["24"]="rgb24" ["32"]="rgba" ["48"]="rgb48le" ["64"]="rgb64le")

generateImage ()
{
	pixFmt=""

	if [ $imageFormat = "Bitmap" ]
	then
		if [ $imageBitDepth != "0" ]
		then
			pixFmt=$(echo "-pix_fmt" ${pixFmts[$imageBitDepth]})
		fi
		cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight $pixFmt "output/"$fileName)

	# TODO Need to check whether all the cases for GIF is covered
	# 1) Interlacing
	# 2) Transparency
	# 3) Anti-aliasing
	# 4) Animated
	# 5) Redundancy
	# 6) Basic
	elif [ $imageFormat = "GIF" ]
	then
		cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight "-t 1 output/"$fileName)

	elif [ $imageFormat = "WebP" ]
	then
		cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "output/"$fileName)

	elif [ $imageFormat = "JPEG" ]
	then
		if [ $imageChromaSubSampling = "NA" ]
		then
			#skip chroma and colorspace configuration, input file config will be taken
			cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight "output/"$fileName)
		else
			cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight "-pix_fmt "$imageColorSpace$imageChromaSubSampling"p" "output/"$fileName)
		fi

	elif [ $imageFormat = "PNG" ]
	then
		if [ $imageBitDepth != "0" ]
		then
			pixFmt=$(echo "-pix_fmt" ${pixFmts[$imageBitDepth]})
		fi
		cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight $pixFmt "output/"$fileName)
	else
		#skipping color space, chroma configurations
		cmdToGenerateImage=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$imageWidth":"$imageHeight "output/"$fileName)
	fi

	echo "executing ffmpeg cmd:" $cmdToGenerateImage
	$cmdToGenerateImage
	echo "Return value = $?"
}


declare -A audioCodecs=( ["mp3"]="-acodec libmp3lame" ["aac"]="-acodec libfdk_aac" )
# list of Audio codecs supported
# 3gp
# aac
# ac3
# asf
# avi
# dsf
# flac
# m2ts
# m4a
# m4b
# MID
# mkv
# mp3
# mp4
# ogg
# ra
# rm
# rmvb
# ts
# wav
# wma	-- Covers wmadec, wmastddec, wmaprodec, wmalosslessdec
#
declare -A audioWavBitRates=( ["1"]="" ["4"]="" ["8"]="" ["16"]="pcm_s16le" ["24"]="pcm_s24le" ["32"]="pcm_s32le" ["64"]="pcm_s64le" )

generateAudio ()
{
	audioCodec=""

	if [ $fileType = "mp3" || $fileType = "avi" ]
	then
		audioCodec="-acodec libmp3lame"

	elif [ $fileType = "wav" ]
	then
		audioCodec="-acodec pcm_s16le"

	elif [ $fileType = "aac" || $fileType = "m4a" || $fileType = "m4b" ]
	then
		audioCodec="-acodec libfdk_aac"

	elif [ $fileType = "3gp" ]
	then
		audioCodec="-acodec amr_nb"

	elif [ $fileType = "asf" ]
	then
		audioCodec="-acodec wmav2"

	elif [ $fileType = "dsf" ]
	then
		audioCodec=$(echo "to be started from here")

	elif [ $fileType = "flac" ]
	then
		audioCodec="-acodec flac"

	elif [ $fileType = "m2ts" || $fileType = "ts" ]
	then
		audioCodec="-acodec mp2"

	elif [ $fileType = "mid" ]
	then
		audioCodec=$(echo "to be started from here")

	elif [ $fileType = "mkv" || $fileType = "ogg" ]
	then
		audioCodec="-acodec libvoris"

	elif [ $fileType = "mp4" ]
	then
		audioCodec="-acodec aac"

	elif [ $fileType = "ra" || $fileType = "rm" || $fileType = "ac3" ]
	then
		audioCodec="-acodec ac3"

	elif [ $fileType = "rmvb" ]
	then
		audioCodec=$(echo "to be started from here")

	elif [ $fileType = "wma" ]
	then
		audioCodec="-acodec wmav2"

	else
		echo "Invalid audio codec"
	fi

	cmdToGenerateAudio=$(echo "ffmpeg -hide_banner -loglevel fatal -stream_loop 100 -i " $inputRefMedia "-vn" "-r" $audioSamplingRate "-ac" $audioChannels "-t" $audioDuration "-b:a" $audioBitRate $audioCodec "output/"$fileName)
	echo "executing ffmpeg cmd:" $cmdToGenerateAudio
	$cmdToGenerateAudio
}

declare -A videoCodecs=( ["mp3"]="-acodec libmp3lame" )
# 3gp
# asf
# avi
# divx
# f4v
# flv
# m2t
# m2ts
# m4v
# mkv
# mov
# mp4
# MPEG
# mpg
# rm
# rmvb
# srt			// To be covered separately
# ts
# vob
# webm
# wmv


generateVideo ()
{
	audioFlags=""
	#if the given meta data doesn't have an audio streaming, remove audio stream while generating video
	if [ $audioAvail = "NO" ]
	then
		audioFlags="-an"
	else
		audioFlags=$(echo "-b:a" $audioBitRate "-ac" $audioChannels "-ar" $audioSamplingRate)
	fi

	if [ $videoChromaSubSampling = "NA" ]
	then
		#skip chroma and colorspace configuration, input file config will be taken
		cmdToGenerateVideo=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$videoWidth":"$videoHeight "-r" $videoFrameRate "-aspect" $videoAspectRatio "-t" $videoDuration "-b:v" $videoBitRate $audioFlags "output/"$fileName)
	else
		cmdToGenerateVideo=$(echo "ffmpeg -hide_banner -loglevel fatal -i" $inputRefMedia "-vf scale="$videoWidth":"$videoHeight "-pix_fmt "$videoColorSpace$videoChromaSubSampling"p" "-r" $videoFrameRate "-aspect" $videoAspectRatio "-t" $videoDuration "-b:v" $videoBitRate $audioFlags "output/"$fileName)
	fi

	echo "executing ffmpeg cmd:" $cmdToGenerateVideo
#	$cmdToGenerateVideo
}

generateMedia ()
{
	#Collect all the elements from the file and take action accordingly
	metaMedia=("$@")

	#getting the only filename from the the completename
	fileName=$(basename "${metaMedia[$FILE_NAME]}")
	fileType=$(echo ${fileName,,}|awk -F "." '{print $NF}')
	
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

			#Get the Audio parameters for video file
			getAudioParams

			#Print processed Audio parameters
			printAudioParams

			#Get the subtitle parameters
			getTextParams

			#Print processed subtitle parameters
			printTextParams

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
