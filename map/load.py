from pathlib import Path
from django.contrib.gis.utils import LayerMapping
from .models import CoalClosures, FFE, PPC

layer_maps = [{
    'model': CoalClosures,
    'file': 'Coal_Closure_Energy_Communities_2023v2.csv',
    'field_map': {
        "geoid": "geoid_tract_2020",
        "mine": "Mine_Closure",
        "generator": "Generator_Closure",
        "adjacent": "Adjacent_to_Closure",
        "state_name": "State_Name",
        "county_name": "County_Name",
        "last_update": "date_last_update",
        "version": 'dataset_version',
        "added": 'record_added'
    }
},
{
    'model': FFE,
    'file': 'MSA_NMSA_FFE_EC_2023v2.csv',
    'field_map': {
        "geoid": "geoid_cty_2020",
        "ffe": "ffe_ind_qual",
        "unemp": "ec_ind_qual",
        "state_name": "state_name",
        "county_name": "county_name_2020",
        "date_last": "date_last_",
        "version": 'dataset_ve',
        "added": 'date_recor',
        'geometry': 'POLYGON'
    }
},
{
    'model': PPC,
    'file': 'ppc.csv',
    'field_map': {
        "geoid": "FIPStxt",
        "county_name": "County_name",
        "pp": "Persistent_Poverty_2013",
        "msa": "Metro-nonmetro status, 2013 0=Nonmetro 1=Metro"
    }
}]

def file_path(file_name):
    return Path(__file__).resolve().parent / "data" / file_name

def run(verbose=True):
    for layer in layer_maps:
        lm = LayerMapping(
            layer['model'], 
            file_path(layer['file']), 
            layer['field_map'], 
            transform=False
            )
        lm.save(strict=True, verbose=verbose)