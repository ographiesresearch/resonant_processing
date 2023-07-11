from django.db import models
from django.contrib.gis.db import models

# U.S. Department of Energy (DOE), National Energy Technology 
# Laboratory (NETL), Interagency Working Group on Coal & Power 
# Plant Communities & Economic Revitalization (IWG), U.S. 
# Department of the Treasury, IRA Energy Community Data Layers, 
# 4/3/2023, 
# https://edx.netl.doe.gov/dataset/ira-energy-community-data-layers

class State(models.Model):
    state = models.CharField(
        max_length = 2,
        help_text = "Two-digit state FIPS.",
        blank = False
        )
    # Longest state name is "Massachusetts," at 14.
    state_name = models.CharField(
        max_length = 14,
        help_text = "Longhand state name.",
        blank = True
        )
    
    def geoid(self):
        "Returns GEOID."
        return self.state

    class Meta:
        abstract = True
    
class County(State):
    county = models.CharField(
        max_length = 3,
        help_text = "Three-digit county FIPS.",
        blank = False
        )
    # Longest county names are 14 characters + 7 for ' County'
    county_name = models.CharField(
        max_length = 21,
        help_text = "Longhand county name.",
        blank = True
        )
    
    def geoid(self):
        "Returns GEOID."
        return "".join([self.state, self.county])

    class Meta:
        abstract = True
    
class Tract(County):
    tract = models.CharField(
        max_length = 6,
        help_text = "Six-digit tract FIPS.",
        blank = False
        )
    
    def geoid(self):
        "Returns GEOID."
        return "".join([self.state, self.county, self.tract])

    class Meta:
        abstract = True
    
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

class CoalClosures(Tract, Meta):
    # Coal closure energy communities' layer 
    # https://edx.netl.doe.gov/dataset/dbed5af6-7cf5-4a1f-89bc-a4c17e46256a/resource/28a8eb09-619e-49e5-8ae3-6ddd3969e845
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
        return self.geoid()

class FFE(County, Meta):
    # MSA/Non-MSA layer
    # fossil fuel employment (FFE) & unemployment requirements
    # https://edx.netl.doe.gov/dataset/dbed5af6-7cf5-4a1f-89bc-a4c17e46256a/resource/b736a14f-12a7-4b9f-8f6d-236aa3a84867
    # =====================================
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
        return self.geoid()
    
class PPC(County, Meta):
    # Persistent poverty County
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
        return self.geoid()
    
# A facility owner will meet the geographic criterion 
# if it is located in a Persistent Poverty County
# or in a census tract that is designated in the 
# Climate and Economic Justice Screening Tool (CEJST)
# as disadvantaged based on energy burden and particulate
# matter (PM) 2.5 indicators. 