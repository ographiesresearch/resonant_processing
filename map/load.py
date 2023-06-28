from pathlib import Path
from django.contrib.gis.utils import LayerMapping
from .models import CoalClosures, FFEUnemp

layer_maps = [{
    'model': CoalClosures,
    'file': 'Coal_Closure_Energy_Communities_SHP_2023v2.shp',
    'field_map': {
        "geoid": "geoid_trac",
        "state": "fipstate_2",
        "county": "fipcounty_",
        "tract": "fiptract_2",
        "mine": "Mine_Qual",
        "generator": "Generator_",
        "neighbor": "Neighbor_Q",
        "state_name": "State_Name",
        "county_name": "County_Nam",
        "date_last": "date_last_",
        "version": 'dataset_ve',
        "added": 'record_add',
        'geometry': 'POLYGON'
    }
},
{
    'model': FFEUnemp,
    'file': 'MSA_NMSA_FEE_EC_Status_2023v2.shp',
    'field_map': {
        "geoid": "geoid_cty_",
        "state": "fipstate_2",
        "county": "fipscty_20",
        "ffe": "ffe_ind_qu",
        "unemp": "ec_ind_qua",
        "state_name": "state_name",
        "county_name": "county_nam",
        "date_last": "date_last_",
        "version": 'dataset_ve',
        "added": 'date_recor',
        'geometry': 'POLYGON'
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