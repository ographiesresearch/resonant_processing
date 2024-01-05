#!/bin/bash
# Automate the source creation and tileset publication process.

tilesets upload-source $1 resonant-energy-geographies data/resonant_output.geojson;
tilesets upload-source $1 resonant-energy-additional data/additional_criteria.geojson;
tilesets create $1.resonant-energy --recipe results-recipe.json --name "Resonant Energy Geographies";
tilesets publish $1.resonant-energy;