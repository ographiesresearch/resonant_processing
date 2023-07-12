from django.core.management.base import BaseCommand, CommandError
from map.models import CoalClosures, State, County, Tract
from django.contrib.gis.utils import LayerMapping
import csv
import os

def file_path(file_name):
    return os.path.join("data", file_name)

class Command(BaseCommand):
    help = "downloads data and loads it into db."
    maps = {
        'spatial': [
            {
                'model': State,
                'file': 'states.gpkg',
                'layer': 0,
                'field_map': {
                    "fips": "GEOID",
                    "name": "NAME",
                    "abbrev": "STUSPS",
                    "geometry": "MULTIPOLYGON"
                }
            },
            {
                'model': County,
                'file': 'counties.gpkg',
                'layer': 0,
                'field_map': {
                    "fips": "GEOID",
                    "state_fips": {"fips": "STATEFP"},
                    "name": "NAME",
                    "geometry": "MULTIPOLYGON"
                }
            },
            {
                'model': Tract,
                'file': 'tracts.gpkg',
                'layer': 0,
                'field_map': {
                    "fips": "geoid",
                    "state_fips": {"fips": "statefp"},
                    "county_fips": {"fips": "countyfp"},
                    "geometry": "POLYGON"
                }
            }
        ],
        # 'tabular': [
        #     {
        #         'model': CoalClosures,
        #         'file': 'coal_tracts.csv',
        #         'field_map': {
        #             # "geoid": "geoid_tract_2020",
        #             "mine": "Mine_Closure",
        #             "generator": "Generator_Closure",
        #             "adjacent": "Adjacent_to_Closure",
        #             "state_name": "State_Name",
        #             "county_name": "County_Name",
        #             "last_update": "date_last_update",
        #             "version": 'dataset_version',
        #             "added": 'record_added'
        #         }
        #     },
        # {
        #     'model': FFE,
        #     'file': 'MSA_NMSA_FFE_EC_2023v2.csv',
        #     'field_map': {
        #         "geoid": "geoid_cty_2020",
        #         "ffe": "ffe_ind_qual",
        #         "unemp": "ec_ind_qual",
        #         "state_name": "state_name",
        #         "county_name": "county_name_2020",
        #         "last_update": "date_last_update",
        #         "version": 'dataset_version',
        #         "added": 'record_added',
        #     }
        # },
        # {
        #     'model': PPC,
        #     'file': 'ppc.csv',
        #     'field_map': {
        #         "geoid": "FIPStxt",
        #         "county_name": "County_name",
        #         "pp": "Persistent_Poverty_2013",
        #         "msa": "Metro-nonmetro status, 2013 0=Nonmetro 1=Metro"
        #     }
        # }
        # ]
    }
    def handle(self, *args, **options):
        for type, layers in self.maps.items():
            if type == 'spatial':
                for layer in layers:
                    layer['model'].objects.all().delete()
                    lm = LayerMapping(
                        layer['model'], 
                        file_path(layer['file']), 
                        layer['field_map'],
                        layer = layer['layer']
                        )
                    lm.save(verbose=True, strict=True)
            # if type == 'tabular':
            #     for layer in layers:
            #         layer['model'].objects.all().delete()
            #         with open(file_path(layer['file'])) as file:
            #             reader = csv.DictReader(file)
            #             for row in reader:
            #                 model = layer['model_instance']
            #                 for key, value in layer['field_map'].items():
            #                     model.update(
            #                         **{key:row[value]}
            #                     )
            #                 model.save(verbose=True)