#!/usr/bin/bash

# Check if the input argument is provided
if [ -z "$1" ]; then
    echo "Usage: ./bash_script.sh <input-jp2-file>"
    exit 1
fi

# Input JP2 file path from the command line argument
inputPath=$1
baseName=$(basename "$inputPath" .jp2)

# Generate output file names based on the input file name
outputTiff="${baseName}.tif"
outputPtiff="${baseName}.tiff"

# Step 1: Convert JP2 to TIFF using ImageMagick's convert
convert "$inputPath" "$outputTiff"

# Check if the TIFF conversion was successful
if [ ! -f "$outputTiff" ]; then
    echo "Failed to convert JP2 to TIFF."
    exit 1
else
    echo "Successfully converted JP2 to TIFF: $outputTiff"
fi

# Step 2: Convert TIFF to pyramidal TIFF using vips
vips tiffsave "$outputTiff" "$outputPtiff" --tile --pyramid --compression jpeg --tile-width 256 --tile-height 256

# Check if the pyramidal TIFF conversion was successful
if [ ! -f "$outputPtiff" ]; then
    echo "Failed to create pyramidal TIFF."
    exit 1
else
    echo "Successfully created pyramidal TIFF at $outputPtiff"
fi

# Final output
echo "Conversion process completed. Interim TIFF and final pyramidal TIFF files have been saved."
