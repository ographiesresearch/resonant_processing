#!/bin/bash
# Automate the source creation and tileset publication process.

TILESET=$1".resonant"
ATTR="`cat attr.json`"

{
  echo "Uploading results..."
  tilesets upload-source $1 --replace resonant-geographies "data/resonant_results.geojson"
  echo "Uploading additional selection criteria..."
  tilesets upload-source $1 --replace resonant-additional "data/additional_criteria.geojson"
} && { 
  # If source upload is successful, create tileset.
  echo "Creating tileset using recipe..."
  tilesets create $TILESET --recipe recipe.json --name 'Resonant Energy Geographies' --attribution $ATTR
} && {
  echo "Starting publishing process..."
  # If tileset creation is successful, publish tileset.
  tilesets publish $TILESET
}
