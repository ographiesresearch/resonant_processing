import requests
import os

DATA_DIR = 'data'

FILE_LOCATIONS = {
   "cejst": {
       "longname": "Climate and Economic Justice Screening Tool Data",
       "url": "https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv"
   },
   "ppc": {
       "longname": "Persistent Poverty Counties",
       "url": "https://www.ers.usda.gov/webdocs/DataFiles/48652/2015CountyTypologyCodes.csv"
   },
   "brownfields": {
       "longname": "Brownfields",
       "url": "https://ordsext.epa.gov/FLA/www3/acres_frs.kmz"
   }
   # THESE ARE BASED ON 2020 GEOGRAPHIES
   # Census Tracts (2020): https://edx.netl.doe.gov/resource/28a8eb09-619e-49e5-8ae3-6ddd3969e845/download?authorized=True
   # MSA/NMSA (but by 2020 Counties): https://edx.netl.doe.gov/resource/b736a14f-12a7-4b9f-8f6d-236aa3a84867/download?authorized=True
   # Brownfield KMZ: https://ordsext.epa.gov/FLA/www3/acres_frs.kmz
}

def download_files(files = FILE_LOCATIONS, path = DATA_DIR):
    for source, props in files.items():
        ext = os.path.splitext(props['url'])
        print(f"Downloading {props['longname']} as {source}{ext[1]}. 🚀")
        r = requests.get(props['url'], stream=True)
        with open(os.path.join(path, f'{source}{ext[1]}'), 'wb') as f:
            f.write(r.content)
        print(f"Done. ✔️")

if __name__ == "__main__":
    download_files()