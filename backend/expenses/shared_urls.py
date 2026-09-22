from django.urls import path
from . import collaboration as c, travel_documents as d

urlpatterns = [
    path('<int:trip_id>/pdf-preview/', d.preview, {'shared': True}),
    path('<int:trip_id>/documents/', d.upload, {'shared': True}),
    path('<int:trip_id>/documents/<uuid:document_id>/', d.download, {'shared': True}),
    path('<int:trip_id>/map-preview/', c.map_preview, {'shared': True}),
    path('<int:trip_id>/', c.workspace, {'shared': True}),
    path('<int:trip_id>/session/', c.session),
    path('<int:trip_id>/data/', c.data, {'shared': True}),
    path('<int:trip_id>/history/', c.history, {'shared': True}),
]
