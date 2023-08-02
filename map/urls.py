from django.urls import path
from map.views import TractViewset

urlpatterns = [
    path('tract/<lng>/<lat>/', TractViewset.as_view()),
]
