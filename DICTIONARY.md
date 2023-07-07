# Low-Income Communities (`low_inc`)

+ Geography: Census tract.
+ Data Source: ACS 2016-2020 Estimates.

Calculate low-income communities on the basis of ACS estimates."Low-income" is defined by ["New Markets Tax Credits," Section 45D(e)(1) of IRC](https://www.federalregister.gov/d/01-31391/p-16) as...

> any population census tract if (A) the poverty rate for such tract is at least 20 percent, or (B)(i) in the case of a tract not located within a Metropolitan Area (as hereinafter defined), the median family income for such tract does not exceed 80 percent of statewide median family income, or (ii) in the case of a tract located within a Metropolitan Area, the median family income for such tract does not exceed 80 percent of the greater of statewide median family income or the Metropolitan Area median family income.

In other words, whether a tract is a low-income community is given by...

$$
low\\_inc_t = 
\begin{cases}
    1,& \text{if } (pov\\_rate_t >= 0.2)\text{ or }(inc\\_ratio_t <= 0.8) \\
    0,              & \text{otherwise}
\end{cases}
$$

As such, we need to calculate both the poverty rate (`pov_rate`) and the ratio of tract income to regional income (`inc_ratio`). These are defined below.

## Poverty Rate

The poverty rate is defined as....

$$
pov\\_rate_t = \frac{I_t}{P_t}
$$

...where $I_t$ is [Income in the past 12 months below poverty level (`B17001_002`)](https://www.socialexplorer.com/data/ACS2020_5yr/metadata/?ds=ACS20_5yr&var=B17001002), and $P_t$ [is Population for whom poverty status is determined (`B17001_001`)](https://www.socialexplorer.com/data/ACS2020_5yr/metadata/?ds=ACS20_5yr&var=B17001001).

## Income Ratio

The income ratio is defined as...

$$
inc\\_ratio_t = 
\begin{cases}
  \dfrac{MFI_t}{\max(MFI_s, MFI_m)} & \text{if }\exists MFI_m,\\
  \dfrac{MFI_t}{MFI_s} & \text{otherwise}
\end{cases}
$$

...where $MFI_t$ is a given tract's Median Family Income In The Past 12 Months (MFI, In 2020 Inflation-Adjusted Dollars), $MFI_s$ is the statewide MFI, and $MFI_m$ is the metropolitan statistical area-wide MFI for tracts that lie within MSAs. All are identified by the ACS variable [`B19113_001`](https://www.socialexplorer.com/data/ACS2020_5yr/metadata/?ds=ACS20_5yr&var=B19113001).
