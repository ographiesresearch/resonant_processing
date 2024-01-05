#!/bin/bash
# Automate the source creation and tileset publication process.

TILESET=$1".resonant-energy"

tilesets upload-source $1 resonant-energy-geographies data/resonant_results.geojson
tilesets upload-source $1 resonant-energy-additional data/additional_criteria.geojson
tilesets create $TILESET --recipe recipe.json --name 'Resonant Energy Geographies'
tilesets publish $TILESET