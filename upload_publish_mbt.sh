#!/bin/bash
# Automate the source creation and tileset publication process.

TILESET=$1".resonant"
ATTR="`cat attr.json`"

{
  echo "Uploading results..."
  tilesets upload-source $1 --replace --no-validation resonant-geographies "data/resonant_results.geojson"
  echo "Uploading additional selection criteria..."
  tilesets upload-source $1 --replace --no-validation resonant-additional "data/additional_criteria.geojson"
} && { 
  # If source upload is successful, create tileset.
  echo "Creating tileset using recipe..."
  tilesets create $TILESET --recipe recipe.json --attribution '[
    {
      "text": "See documentation for data attribution.",
      "link": "https://www.resonantenergy.app/documentation"
    }
]' --name 'Resonant Energy Geographies'
} && {
  echo "Starting publishing process..."
  # If tileset creation is successful, publish tileset.
  tilesets publish $TILESET
}
