# EXECUTED ANALYSIS NUMBERS

raw rows=7043 cols=21
TotalCharges blanks = 11
blank TotalCharges rows: tenure values = [0] | MonthlyCharges sum = 455.6

after coerce: nulls in TotalCharges = 11
blank rows all have tenure==0 : True
post-fill: nulls=0, TotalCharges<0 = 0
TotalCharges < MonthlyCharges*tenure tolerance check (tenure>0):
  mean diff=0.15  median=0.00  p1=-190.14  p99=191.46

## INTEGRITY
duplicate customerID = 0
duplicate full rows  = 0
  gender             {'Male': 3555, 'Female': 3488}
  SeniorCitizen      {0: 5901, 1: 1142}
  Partner            {'No': 3641, 'Yes': 3402}
  Dependents         {'No': 4933, 'Yes': 2110}
  PhoneService       {'Yes': 6361, 'No': 682}
  MultipleLines      {'No': 3390, 'Yes': 2971, 'No phone service': 682}
  InternetService    {'Fiber optic': 3096, 'DSL': 2421, 'No': 1526}
  OnlineSecurity     {'No': 3498, 'Yes': 2019, 'No internet service': 1526}
  OnlineBackup       {'No': 3088, 'Yes': 2429, 'No internet service': 1526}
  DeviceProtection   {'No': 3095, 'Yes': 2422, 'No internet service': 1526}
  TechSupport        {'No': 3473, 'Yes': 2044, 'No internet service': 1526}
  StreamingTV        {'No': 2810, 'Yes': 2707, 'No internet service': 1526}
  StreamingMovies    {'No': 2785, 'Yes': 2732, 'No internet service': 1526}
  Contract           {'Month-to-month': 3875, 'Two year': 1695, 'One year': 1473}
  PaperlessBilling   {'Yes': 4171, 'No': 2872}
  PaymentMethod      {'Electronic check': 2365, 'Mailed check': 1612, 'Bank transfer (automatic)': 1544, 'Credit card (automatic)': 1522}
  Churn              {'No': 5174, 'Yes': 1869}
tenure min=0 max=72 nunique=73
MonthlyCharges min=18.25 max=118.75
TotalCharges  min=0.00 max=8684.80
TotalCharges==0 count = 11 ; their tenure values = [0]

## CORE KPIs
customers=7043 churners=1869 churn_rate=26.54%  95% CI [25.52, 27.58]
retained=5174 (73.46%)
avg tenure overall=32.37 median=29
avg tenure churners=17.98 median=10
avg tenure retained=37.57 median=38
avg MonthlyCharges overall=64.76 churn=74.44 retained=61.27
MRR total = 456,116.60
MRR attached to churned customers = 139,130.85 (30.50% of MRR)
annualised revenue at risk (churners x 12 x MC) = 1,669,570.20
avg revenue per churner (MC) = 74.44
CLV-proxy: avg TotalCharges churned = 1,531.80 vs retained = 2,549.91

## SEGMENT ANALYSIS (chi-square + Cramer's V)

### Contract   chi2=1184.6 p=5.86e-258 CramersV=0.410
Churn              n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
Contract                                                                                  
Month-to-month  3875      1655   42.71            55.02                88.55          1.61
One year        1473       166   11.27            20.91                 8.88        0.4200
Two year        1695        48    2.83            24.07                 2.57        0.1100

### gender   chi2=0.5 p=0.487 CramersV=0.008
Churn      n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
gender                                                                            
Female  3488       939   26.92            49.52                50.24          1.01
Male    3555       930   26.16            50.48                49.76        0.9900

### SeniorCitizen   chi2=159.4 p=1.51e-36 CramersV=0.150
Churn             n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
SeniorCitizen                                                                            
0              5901      1393   23.61            83.79                74.53        0.8900
1              1142       476   41.68            16.21                25.47          1.57

### Partner   chi2=158.7 p=2.14e-36 CramersV=0.150
Churn       n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
Partner                                                                            
No       3641      1200   32.96            51.70                64.21          1.24
Yes      3402       669   19.66            48.30                35.79        0.7400

### Dependents   chi2=189.1 p=4.92e-43 CramersV=0.164
Churn          n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
Dependents                                                                            
No          4933      1543   31.28            70.04                82.56          1.18
Yes         2110       326   15.45            29.96                17.44        0.5800

### PaymentMethod   chi2=648.1 p=3.68e-140 CramersV=0.303
Churn                         n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
PaymentMethod                                                                                        
Bank transfer (automatic)  1544       258   16.71            21.92                13.80        0.6300
Credit card (automatic)    1522       232   15.24            21.61                12.41        0.5700
Electronic check           2365      1071   45.29            33.58                57.30          1.71
Mailed check               1612       308   19.11            22.89                16.48        0.7200

### InternetService   chi2=732.3 p=9.57e-160 CramersV=0.322
Churn               n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
InternetService                                                                            
DSL              2421       459   18.96            34.37                24.56        0.7100
Fiber optic      3096      1297   41.89            43.96                69.40          1.58
No               1526       113    7.40            21.67                 6.05        0.2800

### TechSupport   chi2=828.2 p=1.44e-180 CramersV=0.343
Churn                   n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
TechSupport                                                                                    
No                   3473      1446   41.64            49.31                77.37          1.57
No internet service  1526       113    7.40            21.67                 6.05        0.2800
Yes                  2044       310   15.17            29.02                16.59        0.5700

### OnlineSecurity   chi2=850.0 p=2.66e-185 CramersV=0.347
Churn                   n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
OnlineSecurity                                                                                 
No                   3498      1461   41.77            49.67                78.17          1.57
No internet service  1526       113    7.40            21.67                 6.05        0.2800
Yes                  2019       295   14.61            28.67                15.78        0.5500

### PaperlessBilling   chi2=258.3 p=4.07e-58 CramersV=0.191
Churn                n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
PaperlessBilling                                                                            
No                2872       469   16.33            40.78                25.09        0.6200
Yes               4171      1400   33.57            59.22                74.91          1.26

### tenure   chi2=945.1 p=6.71e-201 CramersV=0.366
Churn      n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
tenure                                                                            
0-6     1481       784   52.94            21.03                41.95          1.99
7-12     705       253   35.89            10.01                13.54          1.35
13-24   1024       294   28.71            14.54                15.73          1.08
25-36    832       180   21.63            11.81                 9.63        0.8200
37-48    762       145   19.03            10.82                 7.76        0.7200
49-60    832       120   14.42            11.81                 6.42        0.5400
61-72   1407        93    6.61            19.98                 4.98        0.2500

### MonthlyCharges   chi2=427.2 p=3.69e-91 CramersV=0.246
Churn              n  churners  rate_%  share_of_base_%  share_of_churners_%  lift_vs_base
MonthlyCharges                                                                            
<30             1653       162    9.80            23.47                 8.67        0.3700
30-49            641       199   31.05             9.10                10.65          1.17
50-69           1158       234   20.21            16.44                12.52        0.7600
70-89           1847       701   37.95            26.22                37.51          1.43
90+             1744       573   32.86            24.76                30.66          1.24

### tenure: churners by year of tenure
Churn     No   Yes     n  rate_%
tenure                          
0         11     0    11  0.0000
1-12    1138  1037  2175   47.68
13-24    730   294  1024   28.71
25-36    652   180   832   21.63
37-48    617   145   762   19.03
49-60    712   120   832   14.42
61-72   1314    93  1407    6.61
churners with tenure<=12: 1037 = 55.48% of all churners
customers with tenure<=12: 2186 = 31.04% of base

### CONTRACT x TENURE-BAND churn rate
tenure              0   1-12  13-24  25-36  37-48  49-60  61-72
Contract                                                       
Month-to-month    NaN  51.40  37.70  32.50  33.50  27.80  22.20
One year       0.0000  10.60   8.10   8.00  13.10  13.70  12.10
Two year       0.0000 0.0000 0.0000   2.10   2.20   4.00   3.10

### CONTRACT x TENURE-BAND customer counts
tenure           0  1-12  13-24  25-36  37-48  49-60  61-72
Contract                                                   
Month-to-month   0  1994    737    486    316    234    108
One year         1   123    197    250    268    321    313
Two year        10    58     90     96    178    277    986

### MonthlyCharges: quartiles
Churn              No  Yes     n  rate_%
MonthlyCharges                          
(18.249, 35.5]   1564  198  1762   11.24
(35.5, 70.35]    1332  434  1766   24.58
(70.35, 89.85]   1098  659  1757   37.51
(89.85, 118.75]  1180  578  1758   32.88

### MULTI-SERVICE BUNDLE: services count vs churn
n_services distribution: {0: 80, 1: 1701, 2: 1188, 3: 965, 4: 922, 5: 908, 6: 676, 7: 395, 8: 208}
Churn         No  Yes     n  rate_%
n_services                         
0             45   35    80   43.75
1           1342  359  1701   21.11
2            798  390  1188   32.83
3            613  352   965   36.48
4            633  289   922   31.34
5            676  232   908   25.55
6            524  152   676   22.49
7            346   49   395   12.41
8            197   11   208    5.29

## DRIVER MODEL (logistic regression, odds ratios)
design matrix: 7043 x 30
AUC train=0.8487  test=0.8446   (baseline 0.5; majority-class accuracy = 73.46%)

Top drivers by |coef| (standardised):
                                        coef  odds_ratio
tenure                                 -1.42      0.2420
TotalCharges                          0.6820        1.98
Contract_Two year                    -0.5870      0.5560
InternetService_Fiber optic           0.5730        1.77
MonthlyCharges                       -0.4860      0.6150
Contract_One year                    -0.2720      0.7620
StreamingMovies_Yes                   0.1780        1.19
StreamingTV_Yes                       0.1720        1.19
PaperlessBilling_Yes                  0.1680        1.18
MultipleLines_Yes                     0.1620        1.18
OnlineSecurity_Yes                   -0.1460      0.8640
PaymentMethod_Electronic check        0.1450        1.16
TechSupport_Yes                      -0.1350      0.8740
SeniorCitizen                         0.0790        1.08
Dependents_Yes                       -0.0700      0.9320
OnlineBackup_No internet service     -0.0700      0.9330
OnlineSecurity_No internet service   -0.0700      0.9330
DeviceProtection_No internet service -0.0700      0.9330

risk tier distribution:
           customers  churners  rate_%  mr_monthly
risk_tier                                         
Low             4017       329    8.19  228,222.95
Medium          1467       507   34.56  102,931.45
High            1389       889   64.00  109,709.35
Critical         170       144   84.71   15,252.85

## EXPLAINABLE HIGH-RISK SEGMENT (no model)
                                  segment  customers  churners  churn_rate_%  base_share_%  churner_share_%   lift        mrr
                         M2M & tenure<=12       1994      1024         51.35         28.31            54.79   1.94 116,086.50
                 M2M & tenure<=12 & Fiber        916       643         70.20         13.01            34.40   2.65  75,183.15
M2M & tenure<=12 & Fiber & no TechSupport        833       592         71.07         11.83            31.67   2.68  67,629.90
                   M2M & Electronic check       1850       994         53.73         26.27            53.18   2.02 138,730.55
                             M2M & MC>=70       2104      1111         52.80         29.87            59.44   1.99 184,014.80
                          2yr & tenure>24       1537        48          3.12         21.82             2.57 0.1200  97,993.90

Top 2863 customers (40.7% of base, scored by model) contain 80% of churners.
Top 20% of customers by risk capture 51.3% of churners

exported clean=(7043, 22) scored=(7043, 25)