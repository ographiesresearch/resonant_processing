from django.db import models
from django.contrib.gis.db import models

class States(models.Model):
    geoid = models.CharField(
        max_length = 2,
        help_text = "Two-digit state FIPS.",
        primary_key = True
        )
    # Longest state name is "Massachusetts," at 14.
    state_name = models.CharField(
        max_length = 14,
        help_text = "Longhand state name.",
        blank = True
        )
    
    geometry = models.MultiPolygonField()
    def geoid(self):
        "Returns GEOID."
        return self.state
    
class Counties(models.Model):
    state_geoid = models.ForeignKey(
        States,
        on_delete = models.CASCADE
        )
    geoid = models.CharField(
        max_length = 5,
        help_text = "Five-digit county FIPS.",
        primary_key = True
        )
    # Longest county names are 14 characters + 7 for ' County'
    county_name = models.CharField(
        max_length = 21,
        help_text = "Longhand county name.",
        blank = True
        )
    geometry = models.MultiPolygonField()
    
class Tracts(models.Model):
    state_geoid = models.ForeignKey(
        States,
        on_delete = models.CASCADE
        )
    county_geoid = models.ForeignKey(
        Counties,
        on_delete = models.CASCADE
        )
    geoid = models.CharField(
        max_length = 6,
        help_text = "Six-digit tract FIPS.",
        primary_key = True
        )
    geometry = models.MultiPolygonField()
    
class Meta(models.Model):
    last_update = models.DateField(
        help_text = """
            Date last updated (n.b., reflects data as acquired,
            not this database instance).
            """,
        blank = True
        )
    version = models.DecimalField(
        max_digits = 5, 
        decimal_places = 1,
        help_text = "Dataset version.",
        blank = True
        )
    added = models.DateField(
        help_text = """
            Date added (n.b., reflects data as acquired,
            not this database instance).
            """,
        blank = True
        )

    class Meta:
        abstract = True

class CoalClosures(Meta):
    # Coal closure energy communities' layer 
    tract_geoid = models.ForeignKey(
        Tracts,
        on_delete = models.CASCADE
        )
    mine = models.BooleanField(
        help_text = """
            Whether a coal mine has closed after 1999.
            """
        )
    generator = models.BooleanField(
        help_text = """
            Whether a coal-fired electric generating unit
            has been retired after 2009.
            """
        )
    adjacent = models.BooleanField(
        help_text = """
            Whether tract adjoins coal closure tract.
            """
        )
    def energy_community(self):
        "Returns whether tract is energy community."
        if self.mine or self.generator:
            return True

    # Represents tract as geoid string.
    def __str__(self):
        return self.tract_geoid()

class FFE(Meta):
    # fossil fuel employment (FFE) & unemployment requirements
    county_geoid = models.ForeignKey(
        Counties,
        on_delete = models.CASCADE
    )
    msa = models.BooleanField(
        help_text = """
            Whether county is MSA or non-MSA.
            """
        )
    ffe = models.BooleanField(
        help_text = """
            >= 0.17pct direct emp | >= 25pct local tax revs 
            related to coal, oil, or natural gas;
            """
        )
    unemp = models.BooleanField(
        help_text = """
            County unemployment rate >= nat'l avg?
            """
        )
    def energy_community(self):
        "Returns whether county is energy community."
        if self.ffe and self.unemp:
            return True

    # Represents county as geoid string.
    def __str__(self):
        return self.county_geoid()
    
class PPC(Meta):
    # Persistent poverty County
    county_geoid = models.ForeignKey(
        Counties,
        on_delete = models.CASCADE
    )
    msa = models.BooleanField(
        help_text = """
            Whether county is MSA or non-MSA.
            """
        )
    pp = models.BooleanField(
        help_text = """
            Whether county is persistent poverty county 
            """
        )
    
    # Represents county as geoid string.
    def __str__(self):
        return self.county_geoid()