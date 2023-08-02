from rest_framework.serializers import ModelSerializer
from rest_framework_gis.serializers import GeoFeatureModelSerializer

from map.models import Tract

class TractSerializer(GeoFeatureModelSerializer):
    class Meta:
        model = Tract
        geo_field = 'geometry'
        fields = '__all__' 