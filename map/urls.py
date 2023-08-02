from django.urls import path
from map.views import TractViewset

urlpatterns = [
    path('tract', TractViewset.as_view()),
]
