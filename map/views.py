# from django.shortcuts import render
from map.models import Tract
from map.serializers import TractSerializer
from rest_framework import generics
from django.core.exceptions import ValidationError
from django.contrib.gis.geos import Point

class TractViewset(generics.ListAPIView):
    serializer_class = TractSerializer

    def get_queryset(self):
        lng = float(self.kwargs['lng'])
        try:
            lng = float(self.kwargs['lng'])
            lat = float(self.kwargs['lat'])
            pnt = Point(lng, lat)
        except:
            raise ValidationError(message='Failed to create point from lng/lat.')
       
        return Tract.objects.filter(geometry__intersects=pnt)