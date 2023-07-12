from django.contrib import admin
from .models import State, County, Tract

# Register your models here.
admin.site.register(State)
admin.site.register(County)
admin.site.register(Tract)