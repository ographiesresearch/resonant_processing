from django.core.management.base import BaseCommand, CommandError
from map.models import CoalClosures, State, County, Tract
from django.contrib.gis.utils import LayerMapping
import csv
import os

def file_path(file_name):
    return os.path.join("data", file_name)

class Command(BaseCommand):
    help = "downloads data and loads it into db."
    spatial_layers = [
        {
            'model': State,
            'file': 'states.gpkg',
            'layer': 0,
            'field_map': {
                "fips": "geoid",
                "name": "name",
                "abbrev": "stusps",
                "geometry": "MULTIPOLYGON"
            }
        },
        {
            'model': County,
            'file': 'counties.gpkg',
            'layer': 0,
            'field_map': {
                "fips": "geoid",
                "state_fips": {"fips": "statefp"},
                "name": "name",
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
                "geometry": "MULTIPOLYGON"
            }
        }
    ]
    tabular_layers = [
        {
            'model': CoalClosures,
            'file': 'coal_tracts.csv',
            'field_map': {
                "tract_fips": {"fips": "geoid_tract_2020"},
                "mine": "Mine_Closure",
                "generator": "Generator_Closure",
                "adjacent": "Adjacent_to_Closure",
                # "last_update": "date_last_update",
                "version": 'dataset_version',
                # "added": 'record_added'
            }
        },
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
    ]
    def handle(self, *args, **options):
        for layer in self.spatial_layers:
            layer['model'].objects.all().delete()
            lm = LayerMapping(
                layer['model'], 
                file_path(layer['file']), 
                layer['field_map'],
                layer = layer['layer']
                )
            lm.save(verbose=True)
        for layer in self.tabular_layers:
            layer['model'].objects.all().delete()
            with open(file_path(layer['file'])) as file:
                reader = csv.DictReader(file)
                for row in reader:
                    model = layer['model']()
                    for key, value in layer['field_map'].items():
                        if not type(value) is dict:
                            if row[value] == "Yes":
                                row[value] = True
                            elif row[value] == "No":
                                row[value] = False
                            setattr(model, key, row[value])
                        else:
                            model_field = key
                            fk = list(value.keys())[0]
                            print(fk)
                            file_field = list(value.values())[0]
                            print(file_field)
                            print(model_field, fk, row[file_field])
                            setattr(model, model_field + "_id", row[file_field])
                    model.save()