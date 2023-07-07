import requests
import os

DATA_DIR = 'data'

FILES = {
   "cejst": {
       "longname": "Climate and Economic Justice Screening Tool Data",
       "url": "https://static-data-screeningtool.geoplatform.gov/data-versions/1.0/data/score/downloadable/1.0-communities.csv"
   },
   "ppc": {
       "longname": "Persistent Poverty Counties",
       "url": "https://www.ers.usda.gov/webdocs/DataFiles/48652/2015CountyTypologyCodes.csv"
   }
}

def download_csvs(files = FILES, path = DATA_DIR):
    for source, props in files.items():
        print(f"Downloading {props['longname']} as {source}.csv. 🚀")
        r = requests.get(props['url'], stream=True)
        with open(os.path.join(path, f'{source}.csv'), 'wb') as f:
            f.write(r.content)
        print(f"Done. ✔️")

if __name__ == "__main__":
    download_csvs()