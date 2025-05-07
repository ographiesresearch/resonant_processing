# Data Acquisition and Processing for `resonantenergy.app`



[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT) [![Project Status: Inactive – The project has reached a stable, usable state but is no longer being actively developed; support/maintenance will be provided as time allows.](https://www.repostatus.org/badges/latest/inactive.svg)](https://www.repostatus.org/#inactive)

This repository is the home of an R script that download and process data for a mapping application for Resonant Energy that makes geographic criteria for the low-income communities bonus energy investment credit and the energy communities programs queryable by a user. Running the script is time-consuming and memory-intensive. (It took approximately 2 hours on a 2021 Apple M1 with 64 GB of memory.) Speeding this up would be great (many of the geometric set operations are substantially faster in QGIS), but not a priority at the moment.

Once you run the R script, you can push the results to Mapbox as a tilset using the [Mapbox Tilsets Command Line Interface (CLI)](https://docs.mapbox.com/help/tutorials/get-started-mts-and-tilesets-cli/). This should allow you to circumvent the 300 megabyte upload limit enforced by the web interface. First, upload the data. Assuming that you've run the script and that you have a Mapbox secret token that includes the `tilesets:write`, `tilesets:read`, and `tilesets:list` scopes, you can upload the two necessary layers as Mapbox tileset sources using the following commands:

```bash
# set your Mapbox token environment variable
export MAPBOX_ACCESS_TOKEN=<YOUR_MAPBOX_ACCESS_TOKEN>
# navigate to the repository folder
cd <PATH_TO_REPO>
# upload the results as source
tilesets upload-source <YOUR_USERNAME> resonant-energy-geographies data/resonant_output.geojson
# {"id": "mapbox://tileset-source/YOUR_USERNAME/resonant-energy-geographies", "files": 1, "source_size": 255920959, "file_size": 255920959}
tilesets upload-source <YOUR_USERNAME> resonant-energy-additional data/additional_criteria.geojson
# {"id": "mapbox://tileset-source/YOUR_USERNAME/resonant-energy-additional", "files": 1, "source_size": 137266361, "file_size": 137266361}
```

The data needs to then be transformed into vector tiles. I've provided a 'recipe' for generating these on the Mapbox Tile Server (MTS) in `results-receipe.json`---before running the next step, replace my username with yours. Note that this creates a [multilayer tileset](https://docs.mapbox.com/mapbox-tiling-service/examples/bathymetry/). Once you've replaced my username in `results-recipe.json` run the following:

```bash
tilesets create <YOUR USERNAME>.resonant-energy --recipe results-recipe.json --name "Resonant Energy Geographies"
# {"message": "Successfully created empty tileset YOUR_USERNAME.resonant-energy. Publish your tileset to begin processing your data into tiles."}
```

If you log in to Mapbox Studio, you'll see your tileset on the tilesets page, but clicking on it, you'll be informed that it hasn't yet been published. This is the final step. You can put your tileset into the publish queue using this command:

```bash
tilesets publish <YOUR USERNAME>.resonant-energy
# {"message": "Processing ericrobskyhuntley.resonant-energy", "jobId": "clr0spt2o000j08jl5rip7qeg"}
#
# ✔ Tileset job received. Visit https://studio.mapbox.com/tilesets/ericrobskyhuntley.resonant-energy-geographies or run tilesets job ericrobskyhuntley.resonant-energy-geographies clr0spt2o000j08jl5rip7qeg to view the status of your tileset.
```

Now, all you have to do is wait. If you want to do all of the above in one fell swoop, I've provided a shell script to which you can pass your username.

```bash
user@bash: ./mapbox_tileset.sh <YOUR USERNAME>
```
